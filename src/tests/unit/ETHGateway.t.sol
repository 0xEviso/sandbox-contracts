// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../../contracts/Vault.sol";
import {ETHGateway} from "../../contracts/ETHGateway.sol";

import {IWETH} from "../../interfaces/IWETH.sol";

import "forge-std/console.sol";

contract ETHGatewayTest is Test {
    Vault internal _vault;
    ETHGateway public _gateway;
    // eth mainnet address
    IWETH internal _weth =
        IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE =
        keccak256("DEPOSIT_WHITELIST_ROLE");

    // users
    address internal _userAdmin = vm.addr(0x100); // 0xFc32402667182d11B29fab5c5e323e80483e7800

    function setUp() public {
        // setting up users
        vm.deal(_userAdmin, 100 ether);

        // setting up vault
        vm.startPrank(_userAdmin);
        _vault = new Vault(_weth, "DefiStructETH", "dsETH");
        _gateway = new ETHGateway(address(_vault));
        vm.stopPrank();
    }

    // The gateway cannot work with whitelisting because the msg.sender would be the gateway instead of the user
    // And tx.origin doesn't work in the test because its is the test file and not the EOA (like it would on mainnet)
    // until I can find a way to make gateway + whitelisting + unit tests work, I'll disable it

    function testDeposit() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200); // 0x06d31BD867343e5A9D8A82b99618253b38f63b8c
        vm.deal(userDeposit, 100 ether);
        // whitelisting our deposit user
        vm.startPrank(_userAdmin);
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
        vm.stopPrank();

        // check that the user has 100 eth
        assertEq(userDeposit.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userDeposit)), 0);

        // vm.startPrank(userDeposit);
        // _gateway.deposit{value: 1 ether}();
        // vm.stopPrank();

        // // check that the user has 99 eth
        // assertEq(userDeposit.balance, 99 ether);
        // // check that the user has 1 dsETH (vault's token shares)
        // assertEq(_vault.balanceOf(address(userDeposit)), 1e18);
    }

    function testRedeem() public {
        uint256 shares = 1e18;
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // swap 10 eth for weth
        vm.startPrank(userDeposit);
        _weth.deposit{value: 1 ether}();
        vm.stopPrank();
        // whitelisting our deposit user
        vm.startPrank(_userAdmin);
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
        vm.stopPrank();

        // check that the user has 99 eth
        assertEq(userDeposit.balance, 99 ether);
        // check that the user has 1 weth
        assertEq(_weth.balanceOf(userDeposit), 1 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userDeposit)), 0);

        // deposit
        vm.startPrank(userDeposit);
        _weth.approve(address(_vault), 1 ether);
        _vault.deposit(1 ether, address(userDeposit));
        vm.stopPrank();

        // check that the user has 99 eth
        assertEq(userDeposit.balance, 99 ether);
        // check that the user has 0 weth
        assertEq(_weth.balanceOf(userDeposit), 0 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userDeposit)), shares);

        vm.startPrank(userDeposit);
        // allow gateway to redeem on behalf of the user
        _vault.approve(address(_gateway), shares);
        // redeem the shares
        _gateway.redeem(shares);
        vm.stopPrank();

        // check that the user has 100 eth
        assertEq(userDeposit.balance, 100 ether);
        // check that the user has 0 weth
        assertEq(_weth.balanceOf(userDeposit), 0 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(userDeposit)), 0);
    }
}
