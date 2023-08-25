// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/access/AccessControlEnumerable.sol";
import {SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/utils/math/Math.sol";

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/interfaces/IERC20Metadata.sol";

contract MultiAssetVault is ERC20, AccessControlEnumerable, Pausable {
    using Math for uint256;

    IERC20 private immutable _asset;
    uint8 private immutable _underlyingDecimals;

    // Money management role
    bytes32 public constant CAPITAL_MANAGEMENT_ROLE =
        keccak256("CAPITAL_MANAGEMENT_ROLE");
    // emergency deposit freeze, emergency strategy liquidation...
    bytes32 public constant EMERGENCY_FREEZE_ROLE =
        keccak256("EMERGENCY_FREEZE_ROLE");
    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE =
        keccak256("DEPOSIT_WHITELIST_ROLE");

    // Each strategy added to the vault will have a conrresponding configuration attached to it
    struct StrategyConfig {
        IERC20 asset; // asset of the strategy
        uint256 price; // price of the asset in weth
        uint256 activatedAt; // which block does the strategy becomes active, 0 for inactive
        uint256 totalDebt; // total debt of the strategy
    }

    // mapping of strategies to their configuration
    mapping(address => StrategyConfig) internal _strategies;
    // Array to keep track of all strategies, easier to use than mapping
    address[] internal _strategyList;

    // Event to be emitted when a new strategy is added
    event StrategyAdded(address strategy);
    // Event to be emitted when a strategy is revoked
    event StrategyRevoked(address strategy);

    // strandard erc 4626 constructor
    constructor(
        IERC20 asset_,
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {
        (bool success, uint8 assetDecimals) = _tryGetAssetDecimals(asset_);
        _underlyingDecimals = success ? assetDecimals : 18;
        _asset = asset_;
        // default role for openzeppelin access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Money management role
        _setupRole(CAPITAL_MANAGEMENT_ROLE, msg.sender);
        // emergency deposit freeze, emergency strategy liquidation...
        _setupRole(EMERGENCY_FREEZE_ROLE, msg.sender);
        // Needs to be white-listed to deposit capital
        _setupRole(DEPOSIT_WHITELIST_ROLE, msg.sender);
    }

    /**
     * @dev Attempts to fetch the asset decimals. A return value of false indicates that the attempt failed in some way.
     */
    function _tryGetAssetDecimals(
        IERC20 asset_
    ) private view returns (bool, uint8) {
        (bool success, bytes memory encodedDecimals) = address(asset_)
            .staticcall(
                abi.encodeWithSelector(IERC20Metadata.decimals.selector)
            );
        if (success && encodedDecimals.length >= 32) {
            uint256 returnedDecimals = abi.decode(encodedDecimals, (uint256));
            if (returnedDecimals <= type(uint8).max) {
                return (true, uint8(returnedDecimals));
            }
        }
        return (false, 0);
    }

    /**
     * @dev Decimals are computed by adding the decimal offset on top of the underlying asset's decimals. This
     * "original" value is cached during construction of the vault contract. If this read operation fails (e.g., the
     * asset has not been created yet), a default of 18 is used to represent the underlying asset's decimals.
     *
     * See {IERC20Metadata-decimals}.
     */
    function decimals() public view virtual override(ERC20) returns (uint8) {
        return _underlyingDecimals + _decimalsOffset();
    }

    function _decimalsOffset() internal view virtual returns (uint8) {
        return 0;
    }

    /** @dev See {IERC4626-asset}. */
    function asset() public view virtual returns (address) {
        return address(_asset);
    }

    /** @dev See {IERC4626-totalAssets}. */
    function totalAssets() public view virtual returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    // main user entry point
    function deposit(
        address strategy,
        uint256 assets,
        address receiver
    ) public returns (uint256) {
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
            assets <= maxDeposit(strategy, receiver),
            "Deposit limited to 10e18"
        );

        return 0;

        // uint256 shares = previewDeposit(assets);
        // _deposit(strategy, _msgSender(), receiver, assets, shares);

        // return shares;

        // // calls the original deposit function from openzeppelin
        // return super.deposit(assets, receiver);
    }

    // We limit the deposit to 10e18 per call (steth/reth/sfrxeth all have 18 decimals)
    function maxDeposit(
        address strategy,
        address
    ) public view virtual returns (uint256) {
        // ERC4626 requires maxDeposit() MUST NOT revert.
        if (_strategies[strategy].activatedAt != 0) return 10e18;
        return 0;
    }

    // We limit the deposit to 10e18 per call (steth/reth/sfrxeth all have 18 decimals)
    function maxMint(address) public view virtual returns (uint256) {
        return 10e18;
    }

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
        // add the strategy to the mapping
        _strategies[strategy] = StrategyConfig({
            asset: IERC20(strategy),
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

    function getLowestStrategyAllocation() public returns (address) {
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
    }

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
