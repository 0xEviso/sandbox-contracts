// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";

import {Vault} from "../../contracts/Vault.sol";

import {IWETH} from "../../interfaces/IWETH.sol";

import "forge-std/console.sol";

contract VaultTest is Test {
    Vault internal _vault;
    // eth mainnet address
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

        // setting up vault
        vm.startPrank(_userAdmin);
        _vault = new Vault(_weth, "DefiStructETH", "dsETH");
        vm.stopPrank();
    }

    function testInit() public {
        assertEq(_vault.name(), "DefiStructETH");
        assertEq(_vault.symbol(), "dsETH");
        assertEq(_vault.decimals(), 18);
        assertEq(_vault.totalAssets(), 0);
    }

    function testWhitelisting() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // swap 10 eth for weth
        vm.startPrank(userDeposit);
        _weth.deposit{value: 10 ether}();
        vm.stopPrank();

        // non whitelisted user should not be able to deposit
        vm.startPrank(userDeposit);
        _weth.approve(address(_vault), 10e18);
        vm.expectRevert(bytes("Must have DEPOSIT_WHITELIST_ROLE to deposit"));
        _vault.deposit(1e18, address(userDeposit));
        vm.stopPrank();

        // whitelisting our deposit user
        vm.startPrank(_userAdmin);
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
        vm.stopPrank();

        // whitelisted user should be able to deposit
        vm.startPrank(userDeposit);
        _weth.approve(address(_vault), 10e18);
        _vault.deposit(1e18, address(userDeposit));
        vm.stopPrank();
    }

    function testDeposit() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // swap 10 eth for weth
        vm.startPrank(userDeposit);
        _weth.deposit{value: 10 ether}();
        vm.stopPrank();
        // whitelisting our deposit user
        vm.startPrank(_userAdmin);
        _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
        vm.stopPrank();

        // checks that deposit user funds in the vaults are 0
        assertEq(_vault.totalAssets(), 0);
        assertEq(_vault.balanceOf(userDeposit), 0);

        // deposit
        vm.startPrank(userDeposit);
        _weth.approve(address(_vault), 1 ether);
        _vault.deposit(1 ether, address(userDeposit));
        vm.stopPrank();

        // checks that deposit user funds in the vaults are 1 eth equivalent
        assertEq(_vault.totalAssets(), 1 ether);
        assertEq(_vault.balanceOf(userDeposit), 1 ether);
    }

    function testAddStrategy() public {
        // add strategy
        // todo: create a REAL strategy
        address strategy = vm.addr(0x200);

        // setup our deposit user
        address userCapitalManagement = vm.addr(0x200);
        // give 100 eth
        vm.deal(userCapitalManagement, 100 ether);

        // only user with CAPITAL_MANAGEMENT_ROLE ca call the function
        vm.startPrank(userCapitalManagement);
        vm.expectRevert(bytes("Must have CAPITAL_MANAGEMENT_ROLE to add strategy"));
        _vault.addStrategy(strategy);
        vm.stopPrank();

        // whitelisting our capital management user
        vm.startPrank(_userAdmin);
        _vault.grantRole(CAPITAL_MANAGEMENT_ROLE, userCapitalManagement);
        vm.stopPrank();

        // should now work correctly
        vm.startPrank(userCapitalManagement);
        _vault.addStrategy(strategy);
        vm.stopPrank();

        // todo:  check for event
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
