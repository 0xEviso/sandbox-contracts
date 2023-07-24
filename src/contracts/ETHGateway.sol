// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../interfaces/IWETH.sol";
import "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";

contract ETHGateway {
    ERC4626 public immutable _vault;
    IWETH public immutable _weth;

    constructor(address vault_) {
        address payable weth_ = payable(ERC4626(vault_).asset());
        _vault = ERC4626(vault_);
        _weth = IWETH(weth_);
        _weth.approve(vault_, type(uint256).max);
    }

    fallback() external payable {
        _deposit(msg.sender, msg.value);
    }

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function deposit() public payable {
        _deposit(msg.sender, msg.value);
    }

    function _deposit(address sender, uint256 amount) internal {
        _weth.deposit{value: amount}();
        _vault.deposit(amount, sender);
    }

    function withdraw(uint256 amount) public {

    }
}
