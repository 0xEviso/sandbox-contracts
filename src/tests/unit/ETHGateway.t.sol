// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../../contracts/Vault.sol";
import {ETHGateway} from "../../contracts/ETHGateway.sol";

import {IWETH} from "../../interfaces/IWETH.sol";

import "forge-std/console.sol";

contract ETHGatewayTest is Test {
    Vault internal _vault;
    ETHGateway public _gateway;
    // eth mainnet address
    IWETH internal _weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE = keccak256("DEPOSIT_WHITELIST_ROLE");

    // users
    address internal _userAdmin = vm.addr(0x100); // 0xFc32402667182d11B29fab5c5e323e80483e7800
    address internal _userDepositWhitelisted = vm.addr(0x103); // 0xe6eF3a317f91A0a44eB097c8e68B49CcF9E63895

    function setUp() public {
        // setting up users
        vm.deal(_userAdmin, 100 ether);
        vm.deal(_userDepositWhitelisted, 100 ether);

        // setting up vault
        vm.startPrank(_userAdmin);
        _vault = new Vault(_weth, "DefiStructETH", "dsETH");
        _gateway = new ETHGateway(address(_vault));
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, _userDepositWhitelisted);
        vm.stopPrank();
    }

    // The gateway cannot work with whitelisting because the msg.sender would be the gateway instead of the user
    // And tx.origin doesn't work in the test because its is the test file and not the EOA (like it would on mainnet)
    // until I can find a way to make gateway + whitelisting + unit tests work, I'll disable it

    function testDeposit() public {
        // check that the user has 100 eth
        assertEq(_userDepositWhitelisted.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(_userDepositWhitelisted)), 0);

        vm.startPrank(_userDepositWhitelisted);
        _gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the user has 99 eth
        assertEq(_userDepositWhitelisted.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(_userDepositWhitelisted)), 1e18);
    }

    function testRedeem() public {
        uint256 shares = 1e18;

        // check that the user has 100 eth
        assertEq(_userDepositWhitelisted.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(_userDepositWhitelisted)), 0);

        vm.startPrank(_userDepositWhitelisted);
        _gateway.deposit{value: 1 ether}();
        vm.stopPrank();

        // check that the user has 99 eth
        assertEq(_userDepositWhitelisted.balance, 99 ether);
        // check that the user has 1 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(_userDepositWhitelisted)), shares);

        vm.startPrank(_userDepositWhitelisted);
        // allow gateway to redeem on behalf of the user
        _vault.approve(address(_gateway), shares);
        // redeem the shares
        _gateway.redeem(shares);
        vm.stopPrank();

        // check that the user has 100 eth
        assertEq(_userDepositWhitelisted.balance, 100 ether);
        // check that the user has 0 dsETH (vault's token shares)
        assertEq(_vault.balanceOf(address(_userDepositWhitelisted)), 0);
    }
}
