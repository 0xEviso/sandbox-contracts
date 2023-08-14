// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/security/Pausable.sol";
import {AccessControlEnumerable} from "@openzeppelin/access/AccessControlEnumerable.sol";

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

contract Vault is ERC4626, AccessControlEnumerable, Pausable {
    // Money management role
    bytes32 public constant CAPITAL_MANAGEMENT_ROLE = keccak256("CAPITAL_MANAGEMENT_ROLE");
    // emergency deposit freeze, emergency strategy liquidation...
    bytes32 public constant EMERGENCY_FREEZE_ROLE = keccak256("EMERGENCY_FREEZE_ROLE");
    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE = keccak256("DEPOSIT_WHITELIST_ROLE");

    constructor(
        IERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CAPITAL_MANAGEMENT_ROLE, msg.sender);
        _setupRole(EMERGENCY_FREEZE_ROLE, msg.sender);
        _setupRole(DEPOSIT_WHITELIST_ROLE, msg.sender);
    }

    function deposit(uint256 assets, address receiver) public virtual override returns (uint256) {
        require(hasRole(DEPOSIT_WHITELIST_ROLE, msg.sender), "Must have DEPOSIT_WHITELIST_ROLE to deposit");
        return super.deposit(assets, receiver);
    }

    function pauseCapital() public {
        require(hasRole(EMERGENCY_FREEZE_ROLE, msg.sender), "Must have EMERGENCY_FREEZE_ROLE to pause capital");
        _pause();
    }

    function unpauseCapital() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must have DEFAULT_ADMIN_ROLE to unpause capital");
        _pause();
    }
}
