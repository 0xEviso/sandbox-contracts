// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "solmate/mixins/ERC4626.sol";

contract Vault is ERC4626 {
    constructor(ERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset, _name, _symbol) {}

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
