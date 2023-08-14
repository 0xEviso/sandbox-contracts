// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../contracts/Vault.sol";

import {IWETH} from "../mocks/WETH.sol";

import "forge-std/console.sol";

contract VaultTest is Test {
    Vault internal _vault;
    IWETH internal _weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));

    // Money management role
    bytes32 public constant CAPITAL_MANAGEMENT_ROLE = keccak256("CAPITAL_MANAGEMENT_ROLE");
    // emergency deposit freeze, emergency strategy liquidation...
    bytes32 public constant EMERGENCY_FREEZE_ROLE = keccak256("EMERGENCY_FREEZE_ROLE");
    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE = keccak256("DEPOSIT_WHITELIST_ROLE");

    // management roles
    address internal _userAdmin;
    address internal _userCapitalManagement;
    address internal _userEmergencyFreeze;
    // users roles
    address internal _userDepositWhitelisted;
    address internal _userNoRoles;


    function setUp() public {
        // setting up users
        // protocol admin / governance
        _userAdmin = vm.addr(0x100);
        vm.deal(_userAdmin, 100 ether);
        // Vault management
        _userCapitalManagement = vm.addr(0x101);
        vm.deal(_userCapitalManagement, 100 ether);
        // Vault emergency freeze
        _userEmergencyFreeze = vm.addr(0x102);
        vm.deal(_userEmergencyFreeze, 100 ether);
        // Our first deposit user, whitelisted
        _userDepositWhitelisted = vm.addr(0x103);
        vm.deal(_userDepositWhitelisted, 100 ether);
        vm.startPrank(_userDepositWhitelisted);
        _weth.deposit{value: 10 ether}();
        vm.stopPrank();
        // Our second deposit user, non whitelisted
        _userNoRoles = vm.addr(0x104);
        vm.deal(_userNoRoles, 100 ether);
        vm.startPrank(_userNoRoles);
        _weth.deposit{value: 10 ether}();
        vm.stopPrank();

        // setting up vault
        vm.startPrank(_userAdmin);
        _vault = new Vault(_weth, "DefiStructETH", "dsETH");
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, _userDepositWhitelisted);
        vm.stopPrank();
    }

    function testInit() public {
        assertEq(_vault.name(), "DefiStructETH");
        assertEq(_vault.symbol(), "dsETH");
        assertEq(_vault.decimals(), 18);
        assertEq(_vault.totalAssets(), 0);
    }

    function testWhitelisting() public {
        // non whitelisted user should not be able to deposit
        vm.startPrank(_userNoRoles);
        _weth.approve(address(_vault), 10e18);
        vm.expectRevert(bytes("Must have DEPOSIT_WHITELIST_ROLE to deposit"));
        _vault.deposit(1e18, address(_userNoRoles));
        vm.stopPrank();

        // whitelisted user should be able to deposit
        vm.startPrank(_userDepositWhitelisted);
        _weth.approve(address(_vault), 10e18);
        _vault.deposit(1e18, address(_userDepositWhitelisted));
        vm.stopPrank();
    }

    function testDeposit() public {
        assertEq(_vault.totalAssets(), 0);
        assertEq(_vault.balanceOf(_userDepositWhitelisted), 0);

        vm.startPrank(_userDepositWhitelisted);
        _weth.approve(address(_vault), 10e18);
        _vault.deposit(1e18, address(_userDepositWhitelisted));
        vm.stopPrank();

        // // print block number
        // console.log('block  number:', block.number);
        // // try to advance 1 block
        // vm.roll(block.number + 1);
        // // print block number again
        // console.log('block  number:', block.number);

        assertEq(_vault.totalAssets(), 1 ether);
        assertEq(_vault.balanceOf(_userDepositWhitelisted), 1 ether);
    }

    // function testPause() public {
    //     _vault.pauseCapital();
    // }

    // function testPauseRevert() public {
    //     vm.startPrank(_userDepositOne);

    //     vm.expectRevert(bytes("Must have pause capital manager role to pause capital"));
    //     _vault.pauseCapital();

    //     vm.stopPrank();
    // }

}
