// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";

contract Vault is ERC4626 {
    constructor(IERC20 _asset, string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {}
}
