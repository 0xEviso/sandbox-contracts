// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {ICurveTryLSD} from "../interfaces/ICurveTryLSD.sol";
import {IBalCSPool} from "../interfaces/IBalCSPool.sol";
import {IBalMSPool} from "../interfaces/IBalMSPool.sol";
import {ICurvePool1} from "../interfaces/ICurvePool.sol";
import {ICurvePool2} from "../interfaces/ICurvePool.sol";
import {IsfrxETH} from "../interfaces/IsfrxETH.sol";
import {IWstETH} from "../interfaces/IWstETH.sol";

import "forge-std/console.sol";

contract TryLSDGateway {
    ICurveTryLSD internal _tryLSD;
    IBalCSPool internal _ethToWstethBalancerPool =
        IBalCSPool(0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD);
    IBalMSPool internal _ethToRethBalancerPool =
        IBalMSPool(0x1E19CF2D73a72Ef1332C882F20534B6519Be0276);

    IWstETH internal _wsteth;
    IERC20 internal _reth;
    IsfrxETH internal _sfrxeth;

    bool _startedWithdraw;

    constructor(
        address tryLSD_,
        address wsteth_,
        address reth_,
        address sfrxeth_
    ) {
        _tryLSD = ICurveTryLSD(tryLSD_);
        _wsteth = IWstETH(wsteth_);
        _reth = IERC20(reth_);
        _sfrxeth = IsfrxETH(sfrxeth_);

        // _wsteth.approve(address(_tryLSD), type(uint256).max);
        // _reth.approve(address(_tryLSD), type(uint256).max);
        // _sfrxeth.approve(address(_tryLSD), type(uint256).max);
    }

    function swapAndDeposit(uint256[3] memory prices) public payable {}

    function getPrices() public view {
        // console.log(_ethToWstethBalancerPool.getTokenRate(address(_wsteth)));
        // console.log(_ethToRethBalancerPool.getPriceRateCache(address(_reth)));

        // need to get usd price from an external source and feed them to this function
        // we them multiply by token reserves to get the $% of earch token
        // then try to rebalance the pool to 33% each

        console.log("getSFRXETHPrice()", getSFRXETHPrice());
        console.log("getWSTETHPrice()", getWSTETHPrice());
        console.log("getRETHPrice()", getRETHPrice());
    }

    function calculateSwapAmounts(
        uint256 amount
    ) public returns (uint256[3] memory prices_) {
        prices_[0] = _ethToSteth.get_dy(0, 1, amount / 3);
        prices_[1] = _ethToReth.get_dy(0, 1, amount / 3);
        prices_[2] = _ethToFrxeth.get_dy(0, 1, amount / 3);
    }

    ICurvePool1 internal _ethToFrxeth =
        ICurvePool1(0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577);

    function getSFRXETHPrice() public view returns (uint256 price_) {
        // get_dy gives the price of frxeth priced in eth, for 1 eth amount
        price_ = (1e18 * 1e18) / _ethToFrxeth.get_p();
        // then convert eth to sfrxeth
        price_ = (price_ * _sfrxeth.convertToShares(1e18)) / 1e18;
    }

    ICurvePool1 internal _ethToSteth =
        ICurvePool1(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);

    function getWSTETHPrice() public view returns (uint256 price_) {
        // get_dy gives the price of wsteth priced in eth, for 1 eth amount
        price_ = _ethToSteth.get_dy(0, 1, 1e18);
        // then convert eth to wsteth
        price_ = (price_ * _wsteth.tokensPerStEth()) / 1e18;
    }

    ICurvePool2 internal _ethToReth =
        ICurvePool2(0x0f3159811670c117c372428D4E69AC32325e4D0F);

    function getRETHPrice() public view returns (uint256 price_) {
        // get_dy gives the price of reth priced in eth, for 1 eth amount
        price_ = _ethToReth.get_dy(0, 1, 1e18);
    }

    // fallback() external payable {
    //     // only allow deposits though swapAndDeposit()
    //     revert();
    //     // if (_startedWithdraw == false) _deposit(msg.value, msg.sender);
    // }

    // receive() external payable {
    //     // only allow deposits though swapAndDeposit()
    //     revert();
    //     // if (_startedWithdraw == false) _deposit(msg.value, msg.sender);
    // }

    // function deposit() public payable {
    //     _deposit(msg.value, msg.sender);
    // }

    function _deposit(uint256 assets, address receiver) internal {
        console.log("inside TryLSDGateway._deposit()");
        // step 1 check pool balances
        // step 2 calculate swap amounts
        // step 3 swap eth to wsteth
        // step 4 swap eth to reth
        // step 5 swap eth to sfrxeth
        // step 6 add liquidity to pool
        // step 7 transfer shares to receiver
    }
}
