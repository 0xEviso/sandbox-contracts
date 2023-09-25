// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {ICurvePool1} from "../interfaces/ICurvePool.sol";
import {ICurvePool2} from "../interfaces/ICurvePool.sol";

import {IsfrxETH} from "../interfaces/IsfrxETH.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";

import "forge-std/console.sol";

contract TryLSDGateway {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Event to be emitted when a user deposits through the Gateway
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 ethAmount,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                            EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // eth mainnet wsteth
    IWstETH internal _wsteth =
        IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    // eth mainnet steth
    IERC20 internal _steth = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // eth mainnet reth
    IERC20 internal _reth = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);

    // eth mainnet sfrxeth
    IsfrxETH internal _sfrxeth =
        IsfrxETH(0xac3E018457B222d93114458476f3E3416Abbe38F);
    // eth mainnet frxeth
    IERC20 internal _frxeth =
        IERC20(0x5E8422345238F34275888049021821E8E08CAa1f);

    // all the curve pools needed for swaps
    ICurvePool1 internal _ethToSteth =
        ICurvePool1(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    ICurvePool2 internal _ethToReth =
        ICurvePool2(0x0f3159811670c117c372428D4E69AC32325e4D0F);
    ICurvePool1 internal _ethToFrxeth =
        ICurvePool1(0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577);

    // curve tryLSD mainnet pool
    ICurvePool2 internal _tryLSD =
        ICurvePool2(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193);

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        // unlimited approve will be used to add liquidity to the tryLSD pool
        _wsteth.approve(address(_tryLSD), type(uint256).max);
        _reth.approve(address(_tryLSD), type(uint256).max);
        _sfrxeth.approve(address(_tryLSD), type(uint256).max);

        // unlimited approve will be used to wrap steth to wsteth
        _steth.approve(address(_wsteth), type(uint256).max);
        // unlimited approve will be used to wrap frxeth to sfrxeth
        _frxeth.approve(address(_sfrxeth), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function calculatePoolShares(
        uint256 depositAmount
    ) public view returns (uint256 shares) {
        uint256 singleSwapAmount = depositAmount / 3;

        // get_dy gives the price of wsteth priced in eth, for 1 eth amount
        uint256 wstethAmount = _ethToSteth.get_dy(0, 1, singleSwapAmount);
        // then convert eth to wsteth
        wstethAmount = (wstethAmount * _wsteth.tokensPerStEth()) / 1e18;

        // wstethAmount =
        //     (_ethToSteth.get_dy(0, 1, singleSwapAmount) *
        //         _wsteth.tokensPerStEth()) /
        //     1e18;

        // get_dy gives the price of reth priced in eth, for 1 eth amount
        uint256 rethAmount = _ethToReth.get_dy(0, 1, singleSwapAmount);

        // get_dy gives the price of frxeth priced in eth, for 1 eth amount
        uint256 sfrxethAmount = _ethToReth.get_dy(0, 1, singleSwapAmount);
        // then convert eth to sfrxeth
        sfrxethAmount = (sfrxethAmount * _sfrxeth.convertToShares(1e18)) / 1e18;

        shares = _tryLSD.calc_token_amount(
            [wstethAmount, rethAmount, sfrxethAmount],
            true
        );
    }

    function swapAndDeposit(
        address owner,
        uint256 minShares
    ) public payable returns (uint256 shares) {
        uint256 singleSwapAmount = msg.value / 3;

        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 stethAmount = _ethToSteth.exchange{value: singleSwapAmount}(
            0,
            1,
            singleSwapAmount,
            0 // min amount set to 0 because we check pool shares for slippage
        );
        // then wrap to wsteth
        uint256 wstethAmount = _wsteth.wrap(stethAmount);
        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 rethAmount = _ethToReth.exchange_underlying{
            value: singleSwapAmount
        }(
            0,
            1,
            singleSwapAmount,
            0 // min amount set to 0 because we check pool shares for slippage
        );
        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 frxethAmount = _ethToFrxeth.exchange{value: singleSwapAmount}(
            0,
            1,
            singleSwapAmount,
            0 // min amount set to 0 because we check pool shares for slippage
        );
        // then wrap to sfrxeth
        uint256 sfrxethAmount = _sfrxeth.deposit(frxethAmount, address(this));

        // add liquidity to pool
        shares = _tryLSD.add_liquidity(
            [wstethAmount, rethAmount, sfrxethAmount],
            minShares,
            false,
            owner
        );
        // Check slippage
        require(shares >= minShares, "min shares not met");

        // emit deposit event
        emit Deposit(msg.sender, owner, msg.value, shares);
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW LOGIC
    //////////////////////////////////////////////////////////////*/

    // todo
}
