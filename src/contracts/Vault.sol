// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

contract Vault is ERC4626 {
    constructor(IERC20 _asset, string memory _name, string memory _symbol) ERC20(_name, _symbol) ERC4626(IERC20(_asset)) {}
}
