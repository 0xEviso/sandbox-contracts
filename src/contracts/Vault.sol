// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/access/AccessControlEnumerable.sol";

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract Vault is ERC4626, AccessControlEnumerable, Pausable {
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
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {
        // default role for openzeppelin access control
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // Money management role
        _setupRole(CAPITAL_MANAGEMENT_ROLE, msg.sender);
        // emergency deposit freeze, emergency strategy liquidation...
        _setupRole(EMERGENCY_FREEZE_ROLE, msg.sender);
        // Needs to be white-listed to deposit capital
        _setupRole(DEPOSIT_WHITELIST_ROLE, msg.sender);
    }

    // main user entry point
    function deposit(
        uint256 assets,
        address receiver
    ) public virtual override returns (uint256) {
        // check if the user is allowed to deposit
        require(
            hasRole(DEPOSIT_WHITELIST_ROLE, msg.sender),
            "Must have DEPOSIT_WHITELIST_ROLE to deposit"
        );
        // calls the original deposit function from openzeppelin
        return super.deposit(assets, receiver);
    }

    // add a strategy to the vault
    function addStrategy(address strategy) public {
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
