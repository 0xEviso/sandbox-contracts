// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {stETHAccumulatorStrategy} from "../contracts/stETHAccumulatorStrategy.sol";
import {WETH} from "../mocks/WETH.sol";

contract stETHAccumulatorStrategyTest is Test {
    stETHAccumulatorStrategy strategy;
    WETH weth;

    function setUp() public {
        weth = new WETH();
        strategy = new stETHAccumulatorStrategy(weth);
    }

    function testInit() public {
        assertEq(strategy.name(), "stETHAccumulatorStrategy");
        assertEq(strategy.symbol(), "df-stETH-AS");
        assertEq(strategy.decimals(), 18);
        assertEq(strategy.totalAssets(), 0);
    }
}
