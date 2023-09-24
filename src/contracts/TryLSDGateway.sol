// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {ICurvePool1} from "../interfaces/ICurvePool.sol";
import {ICurvePool2} from "../interfaces/ICurvePool.sol";

import {IsfrxETH} from "../interfaces/IsfrxETH.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";

import "forge-std/console.sol";

contract TryLSDGateway {
    IWstETH internal _wsteth;
    IERC20 internal _reth;
    IsfrxETH internal _sfrxeth;

    IERC20 internal _steth = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 internal _frxeth =
        IERC20(0x5E8422345238F34275888049021821E8E08CAa1f);

    ICurvePool1 internal _ethToSteth =
        ICurvePool1(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    ICurvePool2 internal _ethToReth =
        ICurvePool2(0x0f3159811670c117c372428D4E69AC32325e4D0F);
    ICurvePool1 internal _ethToFrxeth =
        ICurvePool1(0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577);

    ICurvePool2 internal _tryLSD =
        ICurvePool2(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193);

    bool _startedWithdraw;

    constructor(
        address tryLSD_,
        address wsteth_,
        address reth_,
        address sfrxeth_
    ) {
        _tryLSD = ICurvePool2(tryLSD_);
        _wsteth = IWstETH(wsteth_);
        _reth = IERC20(reth_);
        _sfrxeth = IsfrxETH(sfrxeth_);

        // unlimited approve will be used to add liquidity to the tryLSD pool
        _wsteth.approve(address(_tryLSD), type(uint256).max);
        _reth.approve(address(_tryLSD), type(uint256).max);
        _sfrxeth.approve(address(_tryLSD), type(uint256).max);

        // unlimited approve will be used to wrap steth to wsteth
        _steth.approve(address(_wsteth), type(uint256).max);
        // unlimited approve will be used to wrap frxeth to sfrxeth
        _frxeth.approve(address(_sfrxeth), type(uint256).max);
    }

    function calculateSwapAmounts(
        uint256 amount
    )
        public
        view
        returns (uint256 stethAmount, uint256 rethAmount, uint256 frxethAmount)
    {
        // calculate swap amounts
        stethAmount = _ethToSteth.get_dy(0, 1, amount / 3);
        rethAmount = _ethToReth.get_dy(0, 1, amount / 3);
        frxethAmount = _ethToFrxeth.get_dy(0, 1, amount / 3);
    }

    function swapAndDeposit(
        address receiver,
        uint256 minStethAmount,
        uint256 minRethAmount,
        uint256 minFrxethAmount
    ) public payable returns (uint256 shares) {
        // swap eth to wsteth
        uint256 wstethAmount = _swapToWsteth(msg.value / 3, minStethAmount);

        // swap eth to reth
        uint256 rethAmount = _swapToReth(msg.value / 3, minRethAmount);

        // swap eth to sfrxeth
        uint256 sfrxethAmount = _swapToSfrxeth(msg.value / 3, minFrxethAmount);

        // todo add liquidity to pool

        // todo emit event
    }

    function _swapToWsteth(
        uint256 assets,
        uint256 minAmount
    ) internal returns (uint256 wstethAmount) {
        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 stethAmount = _ethToSteth.exchange{value: assets}(
            0,
            1,
            assets,
            minAmount
        );
        // then wrap to wsteth
        wstethAmount = _wsteth.wrap(stethAmount);
    }

    function _swapToReth(
        uint256 assets,
        uint256 minAmount
    ) internal returns (uint256 rethAmount) {
        // exchange from eth to steth, target amount and minAmount (for slippage)
        rethAmount = _ethToReth.exchange_underlying{value: assets}(
            0,
            1,
            assets,
            minAmount
        );
    }

    function _swapToSfrxeth(
        uint256 assets,
        uint256 minAmount
    ) internal returns (uint256 sfrxethAmount) {
        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 frxethAmount = _ethToFrxeth.exchange{value: assets}(
            0,
            1,
            assets,
            minAmount
        );

        // then wrap to sfrxeth
        sfrxethAmount = _sfrxeth.deposit(frxethAmount, address(this));
    }
}
