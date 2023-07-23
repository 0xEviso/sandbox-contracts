// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/WETH.sol";
import "../src/ETHGateway.sol";

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
        assertEq(vault.totalAssets(), 0);

        vm.startPrank(userOne);
        gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1e18);
    }
}
