// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/access/AccessControlEnumerable.sol";

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract Vault is ERC4626, AccessControlEnumerable, Pausable {
    // Vault level roles
    // Can add strategies to the vault.
    bytes32 public constant ADD_STRATEGY_MANAGER = keccak256("ADD_STRATEGY_MANAGER");
    // Can remove strategies from the vault.
    bytes32 public constant REVOKE_STRATEGY_MANAGER = keccak256("REVOKE_STRATEGY_MANAGER");
    // Remove funds from a single strategy and send them to the vault.
    bytes32 public constant WITHDRAW_SINGLE_STRATEGY_MANAGER = keccak256("WITHDRAW_SINGLE_STRATEGY_MANAGER");

    // Asset buffer in the vault used for rebalance and withdrawal liquidity.
    bytes32 public constant VAULT_BUFFER_MANAGER = keccak256("VAULT_BUFFER_MANAGER");

    // Replace fund allocator, a separate contract that decides the allocation of capital to strategies.
    bytes32 public constant REPLACE_FUND_ALLOCATOR = keccak256("REPLACE_FUND_ALLOCATOR");
    // Can execute rebalance swap orders.
    bytes32 public constant REBALANCE_MANAGER = keccak256("REBALANCE_MANAGER");

    // Pause all mints and redeems (low threshold).
    bytes32 public constant PAUSE_CAPITAL_MANAGER = keccak256("PAUSE_CAPITAL_MANAGER");
    // Allow all mints and redeems (high threshold).
    bytes32 public constant UNPAUSE_CAPITAL_MANAGER = keccak256("UNPAUSE_CAPITAL_MANAGER");

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        _setupRole(ADD_STRATEGY_MANAGER, msg.sender);
        _setupRole(REVOKE_STRATEGY_MANAGER, msg.sender);
        _setupRole(WITHDRAW_SINGLE_STRATEGY_MANAGER, msg.sender);

        _setupRole(VAULT_BUFFER_MANAGER, msg.sender);

        _setupRole(REPLACE_FUND_ALLOCATOR, msg.sender);
        _setupRole(REBALANCE_MANAGER, msg.sender);

        _setupRole(PAUSE_CAPITAL_MANAGER, msg.sender);
        _setupRole(UNPAUSE_CAPITAL_MANAGER, msg.sender);
    }

    function pauseCapital() public {
        require(hasRole(PAUSE_CAPITAL_MANAGER, msg.sender), "Must have pause capital manager role to pause capital");
        _pause();
    }

    function unpauseCapital() public {
        require(hasRole(UNPAUSE_CAPITAL_MANAGER, msg.sender), "Must have pause capital manager role to unpause capital");
        _pause();
    }
}
