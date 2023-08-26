// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/access/AccessControlEnumerable.sol";

// import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

// Heavily inspired by transmissions11/solmate ERC4626
contract MultiAssetVault is ERC20, AccessControlEnumerable, Pausable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    // Event to be emitted when a new strategy is added
    event StrategyAdded(address strategy);
    // Event to be emitted when a strategy is revoked
    event StrategyRevoked(address strategy);

    event Deposit(
        address indexed strategy,
        address indexed caller,
        address indexed owner,
        uint256 tokens,
        uint256 assets,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                                ROLES
    //////////////////////////////////////////////////////////////*/

    // Money management role
    bytes32 public constant CAPITAL_MANAGEMENT_ROLE =
        keccak256("CAPITAL_MANAGEMENT_ROLE");
    // emergency deposit freeze, emergency strategy liquidation...
    bytes32 public constant EMERGENCY_FREEZE_ROLE =
        keccak256("EMERGENCY_FREEZE_ROLE");
    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE =
        keccak256("DEPOSIT_WHITELIST_ROLE");

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
        // default role for openzeppelin access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Money management role
        _setupRole(CAPITAL_MANAGEMENT_ROLE, msg.sender);
        // emergency deposit freeze, emergency strategy liquidation...
        _setupRole(EMERGENCY_FREEZE_ROLE, msg.sender);
        // Needs to be white-listed to deposit capital
        _setupRole(DEPOSIT_WHITELIST_ROLE, msg.sender);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL
    //////////////////////////////////////////////////////////////*/

    // main user entry point
    function deposit(
        address strategy,
        uint256 tokens,
        address receiver
    ) public returns (uint256 shares) {
        // check if the user is allowed to deposit
        require(
            hasRole(DEPOSIT_WHITELIST_ROLE, msg.sender),
            "Must have DEPOSIT_WHITELIST_ROLE to deposit"
        );
        // check that strategy exists
        require(
            _strategies[strategy].activatedAt != 0,
            "Strategy does not exist or is inactive"
        );
        // check that the deposited asset is the strategy with the lowest allocation
        require(
            getLowestStrategyAllocation() == strategy,
            "Must deposit strategy with lowest allocation"
        );

        // check that the assets is not higher than the max deposit
        require(
            tokens <= maxDeposit(strategy, receiver),
            "Deposit limited to 10e18"
        );

        // Check for rounding error since we round down in previewDeposit.
        require(
            (shares = previewDeposit(strategy, tokens)) != 0,
            "ZERO_SHARES"
        );

        // calculating assets equivalent
        uint256 assets = convertTokensToAssets(strategy, tokens);

        // Need to transfer before minting or ERC777s could reenter.
        _strategies[strategy].asset.safeTransferFrom(
            msg.sender,
            address(this),
            tokens
        );

        // update the total debt of the strategy
        _strategies[strategy].totalDebt += tokens;

        _mint(receiver, shares);

        emit Deposit(strategy, msg.sender, receiver, tokens, assets, shares);
    }

    /*//////////////////////////////////////////////////////////////
                                ACCOUNTING
    //////////////////////////////////////////////////////////////*/

    function totalAssets() public view virtual returns (uint256) {
        return asset.balanceOf(address(this));
    }

    // returns how many shares would be sent back from given strategy and tokens
    function convertToShares(
        address strategy,
        uint256 tokens
    ) public view virtual returns (uint256) {
        uint256 assets = convertTokensToAssets(strategy, tokens);

        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }

    function convertTokensToAssets(
        address strategy,
        uint256 tokens
    ) public view virtual returns (uint256) {
        // check that strategy exists
        if (!(_strategies[strategy].activatedAt != 0)) return 0;
        // calculating assets equivalent by multiplying strategy tokens by their price
        return tokens * _strategies[strategy].price;
    }

    function convertToAssets(
        uint256 shares
    ) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }

    function previewDeposit(
        address strategy,
        uint256 tokens
    ) public view virtual returns (uint256) {
        return convertToShares(strategy, tokens);
    }

    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }

    function previewWithdraw(
        uint256 assets
    ) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());
    }

    function previewRedeem(
        uint256 shares
    ) public view virtual returns (uint256) {
        return convertToAssets(shares);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT/WITHDRAWAL LIMITS
    //////////////////////////////////////////////////////////////*/

    // We limit the deposit to 10e18 per call (steth/reth/sfrxeth all have 18 decimals)
    function maxDeposit(
        address strategy,
        address
    ) public view virtual returns (uint256) {
        // ERC4626 requires maxDeposit() MUST NOT revert.
        if (_strategies[strategy].activatedAt != 0) return 10e18;
        return 0;
    }

    function maxMint(
        address strategy,
        address
    ) public view virtual returns (uint256) {
        // ERC4626 requires maxMint() MUST NOT revert.
        if (_strategies[strategy].activatedAt != 0) return 10e18;
        return 0;
    }

    /*//////////////////////////////////////////////////////////////
                            STRATEGIES
    //////////////////////////////////////////////////////////////*/

    // Each strategy added to the vault will have a conrresponding configuration attached to it
    struct StrategyConfig {
        ERC20 asset; // asset of the strategy
        uint256 price; // price of the asset in weth
        uint256 activatedAt; // which block does the strategy becomes active, 0 for inactive
        uint256 totalDebt; // total debt of the strategy
    }

    // mapping of strategies to their configuration
    mapping(address => StrategyConfig) internal _strategies;
    // Array to keep track of all strategies, easier to use than mapping
    address[] internal _strategyList;

    // add a strategy to the vault
    function addStrategy(address strategy, uint256 price) public {
        // check if the user is allowed to add a strategy
        require(
            hasRole(CAPITAL_MANAGEMENT_ROLE, msg.sender),
            "Must have CAPITAL_MANAGEMENT_ROLE to add strategy"
        );
        // check if the strategy is not already added
        require(
            _strategies[strategy].activatedAt == 0,
            "Strategy already added"
        );
        // todo: add some checks to make sure the address is an ERC20
        // add the strategy to the mapping
        _strategies[strategy] = StrategyConfig({
            asset: ERC20(strategy),
            price: price,
            activatedAt: block.number,
            totalDebt: 0
        });
        // add the strategy to the array
        _strategyList.push(strategy);
        // emit the event
        emit StrategyAdded(strategy);
    }

    // Function to list all strategies
    function strategies() public view returns (address[] memory) {
        return _strategyList;
    }

    // Function to revoke a strategy by its address
    function removeStrategy(address strategy) public {
        // check if the user is allowed to revoke a strategy
        require(
            hasRole(CAPITAL_MANAGEMENT_ROLE, msg.sender),
            "Must have CAPITAL_MANAGEMENT_ROLE to revoke strategy"
        );
        // check if the strategy exists and is not already revoked
        require(
            _strategies[strategy].activatedAt != 0,
            "Strategy does not exist or is inactive"
        );
        // Update the mapping to deactivate the strategy
        _strategies[strategy].activatedAt = 0;
        // emit the event
        emit StrategyRevoked(strategy);
    }

    /*//////////////////////////////////////////////////////////////
                            ALLOCATION
    //////////////////////////////////////////////////////////////*/

    function getLowestStrategyAllocation() public view returns (address) {
        if (_strategyList.length == 0) {
            return address(0);
        }
        uint256 lowestAllocation = 0;
        address lowestStrategy = address(0);
        for (uint256 i = 0; i < _strategyList.length; i++) {
            if (_strategies[_strategyList[i]].totalDebt == 0) {
                return _strategyList[i];
            }
            if (
                lowestStrategy == address(0) ||
                _strategies[_strategyList[i]].totalDebt < lowestAllocation
            ) {
                lowestAllocation = _strategies[_strategyList[i]].totalDebt;
                lowestStrategy = _strategyList[i];
            }
        }
        return lowestStrategy;
    }

    /*//////////////////////////////////////////////////////////////
                            EMERGENCY ACTIONS
    //////////////////////////////////////////////////////////////*/

    function pauseCapital() public {
        require(
            hasRole(EMERGENCY_FREEZE_ROLE, msg.sender),
            "Must have EMERGENCY_FREEZE_ROLE to pause capital"
        );
        _pause();
    }

    function unpauseCapital() public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must have DEFAULT_ADMIN_ROLE to unpause capital"
        );
        _pause();
    }
}
