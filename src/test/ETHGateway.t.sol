// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {PrimaryStrategyVault} from "../contracts/PrimaryStrategyVault.sol";
import {ETHGateway} from "../contracts/ETHGateway.sol";

import {WETH} from "../mocks/WETH.sol";

contract ETHGatewayTest is Test {
    PrimaryStrategyVault public _vault;
    WETH _weth;
    ETHGateway public _gateway;
    address userOne;

    function setUp() public {
        _weth = new WETH();
        _vault = new PrimaryStrategyVault(_weth, "DefiStructETH", "dsETH");
        _gateway = new ETHGateway(address(_vault));

        // setting up a user with eth
        userOne = vm.addr(1);
        vm.deal(userOne, 100 ether);
    }

    function testDeposit() public {
        // check that the vault has 0 eth
        assertEq(_vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userOne)), 0);

        vm.startPrank(userOne);
        _gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the vault has 1 eth
        assertEq(_vault.totalAssets(), 1e18);
        // check that the user has 99 eth
        assertEq(userOne.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userOne)), 1e18);
    }

    function testRedeem() public {
        uint256 shares = 1e18;

        // check that the vault has 0 eth
        assertEq(_vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userOne)), 0);

        vm.startPrank(userOne);
        _gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the vault has 1 eth
        assertEq(_vault.totalAssets(), shares);
        // check that the user has 99 eth
        assertEq(userOne.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userOne)), shares);

        vm.startPrank(userOne);
        // allow gateway to redeem on behalf of the user
        _vault.approve(address(_gateway), shares);
        // redeem the shares
        _gateway.redeem(shares);
        vm.stopPrank();

        // check that the vault has 0 eth
        assertEq(_vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userOne)), 0);
    }
}
