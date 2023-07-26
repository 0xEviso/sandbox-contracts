// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./BaseStrategy.sol";

import "../interfaces/IWETH.sol";

contract stETHAccumulatorStrategy is BaseStrategy {
    constructor(IWETH weth_) BaseStrategy(weth_, "stETHAccumulatorStrategy", "df-stETH-AS") {}
}
