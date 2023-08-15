// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../../contracts/Vault.sol";
import {ETHGateway} from "../../contracts/ETHGateway.sol";

import {WETH} from "../mocks/WETH.sol";

contract ETHGatewayTest is Test {
    Vault public vault;
    WETH weth;
    ETHGateway public gateway;
    address userOne;

    function setUp() public {
        weth = new WETH();
        vault = new Vault(weth, "DefiStructETH", "dsETH");
        gateway = new ETHGateway(address(vault));

        // setting up a user with eth
        userOne = vm.addr(1);
        vm.deal(userOne, 100 ether);
    }

    function testDeposit() public {
        // check that the vault has 0 eth
        assertEq(vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(vault.balanceOf(address(userOne)), 0);

        vm.startPrank(userOne);
        gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the vault has 1 eth
        assertEq(vault.totalAssets(), 1e18);
        // check that the user has 99 eth
        assertEq(userOne.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(vault.balanceOf(address(userOne)), 1e18);
    }

    function testRedeem() public {
        uint256 shares = 1e18;

        // check that the vault has 0 eth
        assertEq(vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(vault.balanceOf(address(userOne)), 0);

        vm.startPrank(userOne);
        gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the vault has 1 eth
        assertEq(vault.totalAssets(), shares);
        // check that the user has 99 eth
        assertEq(userOne.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(vault.balanceOf(address(userOne)), shares);

        vm.startPrank(userOne);
        // allow gateway to redeem on behalf of the user
        vault.approve(address(gateway), shares);
        // redeem the shares
        gateway.redeem(shares);
        vm.stopPrank();

        // check that the vault has 0 eth
        assertEq(vault.totalAssets(), 0);
        // check that the user has 100 eth
        assertEq(userOne.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(vault.balanceOf(address(userOne)), 0);
    }
}
