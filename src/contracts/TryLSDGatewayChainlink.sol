// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {ICurvePool1} from "../interfaces/ICurvePool.sol";
import {ICurvePool2} from "../interfaces/ICurvePool.sol";

import {IsfrxETH} from "../interfaces/IsfrxETH.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";

import {AggregatorV3Interface} from "../interfaces/Chainlink.sol";

import "forge-std/console.sol";

contract TryLSDGatewayChainlink {
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

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 ethAmount,
        uint256 shares
    );

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    // should not send eth directly to this contract, use swapAndDeposit function
    error NotPayable();

    // Minimum amount of eth sent when deposit
    // 0x4b1175db
    error TooLittleEthError();

    // minimum amount of shares not met on swap and deposit
    // 0x8517304e
    error MinSharesSlippageError();

    // Minimum amount of shares sent on withdraw
    // 0xe8471aeb
    error TooLittleSharesError();

    // minimum amount of shares not met on withdraw and swap
    // 0xfe0d2edb
    error MinEthSlippageError();

    // transferFrom failed while withdrawing
    error TransferFromFailed();

    // failed to transfer eth back to user after withdraw and swap
    error FailedToSendEth();

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

    // eth mainnet chainlink oracle for steth/eth
    AggregatorV3Interface internal _oracleStethToEth =
        AggregatorV3Interface(0x86392dC19c0b719886221c78AB11eb8Cf5c52812);
    // eth mainnet chainlink oracle for reth/eth
    AggregatorV3Interface internal _oracleRethToEth =
        AggregatorV3Interface(0x536218f9E9Eb48863970252233c8F271f554C2d0);

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

        // unlimited approve will be used to swap steth to eth
        _steth.approve(address(_ethToSteth), type(uint256).max);
        // unlimited approve will be used to swap reth to eth
        _reth.approve(address(_ethToReth), type(uint256).max);
        // unlimited approve will be used to swap frxeth to eth
        _frxeth.approve(address(_ethToFrxeth), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                            PAYABLE LOGIC
    //////////////////////////////////////////////////////////////*/

    bool _startedWithdraw;

    fallback() external payable {
        if (_startedWithdraw == false)
            _deposit(msg.sender, msg.sender, msg.value);
    }

    receive() external payable {
        if (_startedWithdraw == false)
            _deposit(msg.sender, msg.sender, msg.value);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT LOGIC
    //////////////////////////////////////////////////////////////*/

    function deposit(address owner) public payable returns (uint256 shares) {
        return _deposit(msg.sender, owner, msg.value);
    }

    function _deposit(
        address sender,
        address owner,
        uint256 assets
    ) internal returns (uint256 shares) {
        // should send more than 0 eth
        if (assets == 0) revert TooLittleEthError();

        uint256 singleSwapAmount = assets / 3;

        uint256 wstethAmount = _swapToWsteth(singleSwapAmount);
        uint256 rethAmount = _swapToReth(singleSwapAmount);
        uint256 sfrxethAmount = _swapToSfrxeth(singleSwapAmount);

        // add liquidity to pool
        shares = _tryLSD.add_liquidity(
            [wstethAmount, rethAmount, sfrxethAmount],
            0, // min shares set to 0 because I check myself for slippage
            false,
            owner
        );

        // Check slippage
        // if (shares <= minShares) revert MinSharesSlippageError();

        // emit deposit event
        emit Deposit(sender, owner, assets, shares);
    }

    function _swapToWsteth(
        uint256 ethAmount
    ) internal returns (uint256 lsdAmount) {
        // getting pricing for chainlink oracle
        (, int256 answer, , , ) = _oracleStethToEth.latestRoundData();

        // 0.1% slippage
        uint256 minAmount = (((ethAmount / uint256(answer)) * 1e18) * 999) /
            1000;

        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 stethAmount = _ethToSteth.exchange{value: ethAmount}(
            0,
            1,
            ethAmount,
            minAmount
        );
        // then wrap to wsteth
        lsdAmount = _wsteth.wrap(stethAmount);
    }

    function _swapToReth(
        uint256 ethAmount
    ) internal returns (uint256 lsdAmount) {
        // getting pricing for chainlink oracle
        (, int256 answer, , , ) = _oracleRethToEth.latestRoundData();

        // 0.1% slippage
        uint256 minAmount = (((ethAmount / uint256(answer)) * 1e18) * 999) /
            1000;

        // exchange from eth to steth, target amount and minAmount (for slippage)
        lsdAmount = _ethToReth.exchange_underlying{value: ethAmount}(
            0,
            1,
            ethAmount,
            minAmount
        );
    }

    function _swapToSfrxeth(
        uint256 ethAmount
    ) internal returns (uint256 lsdAmount) {
        // no chainlink oracle for frxeth, we use curve pool oracle instead
        // the price is FROM frxeth TO eth
        uint256 priceOracle = _ethToFrxeth.price_oracle();

        // 0.1% slippage
        uint256 minAmount = (((ethAmount / priceOracle) * 1e18) * 999) / 1000;

        // exchange from eth to steth, target amount and minAmount (for slippage)
        uint256 frxethAmount = _ethToFrxeth.exchange{value: ethAmount}(
            0,
            1,
            ethAmount,
            minAmount
        );
        // then wrap to sfrxeth
        lsdAmount = _sfrxeth.deposit(frxethAmount, address(this));
    }

    /*//////////////////////////////////////////////////////////////
                            WITHDRAW LOGIC
    //////////////////////////////////////////////////////////////*/

    function withdraw(
        address receiver,
        address owner,
        uint256 shares
    ) public returns (uint256 ethAmount) {
        return _withdraw(msg.sender, receiver, owner, shares);
    }

    function _withdraw(
        address sender,
        address receiver,
        address owner,
        uint256 shares
    ) internal returns (uint256 ethAmount) {
        // this variable is to prevent a loop where pool would send eth to the gateway and trigger a deposit
        _startedWithdraw = true;

        // should send more than 0 shares
        if (shares == 0) revert TooLittleSharesError();

        bool success = _tryLSD.transferFrom(owner, address(this), shares);

        // this might be useless as transferFrom will revert itself if it fails
        if (success == false) revert TransferFromFailed();

        uint256[3] memory amounts = _tryLSD.remove_liquidity(
            shares,
            [uint256(0), uint256(0), uint256(0)],
            false,
            address(this)
        );

        uint256 wstethToEthAmount = _swapWstethToEth(amounts[0]);
        uint256 rethToEthAmount = _swapRethToEth(amounts[1]);
        uint256 sfrxethToEthAmount = _swapSfrxethToEth(amounts[2]);
        // total eth from all 3 swaps
        ethAmount = wstethToEthAmount + rethToEthAmount + sfrxethToEthAmount;

        // Check slippage
        // if (ethAmount <= minEth) revert MinEthSlippageError();

        (bool sent, ) = receiver.call{value: ethAmount}("");

        if (sent == false) revert FailedToSendEth();

        // emit withdraw event
        emit Withdraw(sender, receiver, owner, ethAmount, shares);

        // this variable is to prevent a loop where pool would send eth to the gateway and trigger a deposit
        _startedWithdraw = false;
    }

    function _swapWstethToEth(
        uint256 lsdAmount
    ) internal returns (uint256 ethAmount) {
        // unwrap wsteth to steth
        uint256 stethAmount = _wsteth.unwrap(lsdAmount);

        // getting pricing for chainlink oracle
        (, int256 answer, , , ) = _oracleStethToEth.latestRoundData();

        // 0.1% slippage
        uint256 minAmount = (((stethAmount * uint256(answer)) / 1e18) * 999) /
            1000;

        // exchange steth to eth
        ethAmount = _ethToSteth.exchange(
            1, // from steth
            0, // to eth
            stethAmount, // amount we got from unwrapping wsteth
            minAmount
        );
    }

    function _swapRethToEth(
        uint256 lsdAmount
    ) internal returns (uint256 ethAmount) {
        // getting pricing for chainlink oracle
        (, int256 answer, , , ) = _oracleRethToEth.latestRoundData();

        // 0.1% slippage
        uint256 minAmount = (((lsdAmount * uint256(answer)) / 1e18) * 999) /
            1000;

        // exchange reth to eth
        ethAmount = _ethToReth.exchange_underlying(
            1, // from reth
            0, // to eth
            lsdAmount,
            minAmount
        );
    }

    function _swapSfrxethToEth(
        uint256 lsdAmount
    ) internal returns (uint256 ethAmount) {
        // redeem frxeth from sfrxeth
        uint256 frxethAmount = _sfrxeth.redeem(
            lsdAmount,
            address(this),
            address(this)
        );

        // no chainlink oracle for frxeth, we use curve pool oracle instead
        // the price is FROM frxeth TO eth
        uint256 priceOracle = _ethToFrxeth.price_oracle();

        // 0.1% slippage
        uint256 minAmount = (((frxethAmount * priceOracle) / 1e18) * 999) /
            1000;

        // exchange from eth to steth, target amount and minAmount (for slippage)
        ethAmount = _ethToFrxeth.exchange(
            1, // from frxeth
            0, // to eth
            frxethAmount,
            minAmount
        );
    }
}
