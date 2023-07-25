// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../contracts/Vault.sol";
import {WETH} from "../mocks/WETH.sol";

contract VaultTest is Test {
    Vault public vault;
    address userOne;
    WETH weth;

    function setUp() public {
        weth = new WETH();
        vault = new Vault(weth, "DefiStructETH", "dsETH");

        // setting up a user with eth and weth
        userOne = vm.addr(1);
        vm.deal(userOne, 100 ether);
        vm.startPrank(userOne);
        weth.deposit{value: 10 ether}();
        vm.stopPrank();
        assertEq(weth.balanceOf(address(userOne)), 10e18);
    }

    function testInit() public {
        assertEq(vault.name(), "DefiStructETH");
        assertEq(vault.symbol(), "dsETH");
        assertEq(vault.decimals(), 18);
        assertEq(vault.totalAssets(), 0);
    }

    function testDeposit() public {
        assertEq(vault.totalAssets(), 0);

        vm.startPrank(userOne);
        weth.approve(address(vault), 10e18);
        vault.deposit(1e18, address(userOne));
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1e18);
    }
}
