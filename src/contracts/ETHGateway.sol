// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IWETH} from "../interfaces/IWETH.sol";
import {ERC4626} from "@openzeppelin/token/ERC20/extensions/ERC4626.sol";

contract ETHGateway {
    ERC4626 public immutable _vault;
    IWETH public immutable _weth;
    bool _startedWithdraw;

    constructor(address vault_) {
        address payable weth_ = payable(ERC4626(vault_).asset());
        _vault = ERC4626(vault_);
        _weth = IWETH(weth_);
        _weth.approve(vault_, type(uint256).max);
    }

    fallback() external payable {
        if (_startedWithdraw == false)
            _deposit(msg.value, msg.sender);
    }

    receive() external payable {
        if (_startedWithdraw == false)
            _deposit(msg.value, msg.sender);
    }

    function deposit() public payable {
        _deposit(msg.value, msg.sender);
    }

    function _deposit(uint256 assets, address receiver) internal {
        _weth.deposit{value: assets}();
        _vault.deposit(assets, receiver);
    }

    function redeem(uint256 shares) public {
        // this variable is to prevent a loop where to unwrapping weth would send eth to the gateway and trigger a deposit
        _startedWithdraw = true;
        // withdraw weth from the vault to the gateway
        uint256 assets = _vault.redeem(shares, address(this), msg.sender);
        // convert to eth
        _weth.withdraw(assets);
        // send to user
        payable(msg.sender).transfer(assets);

        _startedWithdraw = false;
    }
}
