// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {Vault} from "../../contracts/Vault.sol";

import {IWETH} from "../../interfaces/IWETH.sol";
import {IVault} from "../../interfaces/IVault.sol";

import "forge-std/console.sol";

contract VaultTest is Test {
    // Vault related variables
    Vault internal _vault;
    // Event to be emitted when a new strategy is added
    event StrategyAdded(address strategy);
    // Event to be emitted when a strategy is revoked
    event StrategyRevoked(address strategy);

    // eth mainnet address
    IWETH internal _weth = IWETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)); // eth mainnet weth
    IERC20 internal _steth = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84); // eth mainnet steth
    IERC20 internal _reth = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393); // eth mainnet reth
    IERC20 internal _sfrxeth = IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F); // eth mainnet sfrxeth

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
        // setup our deposit user
        address userCapitalManagement = vm.addr(0x201);
        // give 100 eth
        vm.deal(userCapitalManagement, 100 ether);

        // only user with CAPITAL_MANAGEMENT_ROLE ca call the function
        vm.startPrank(userCapitalManagement);
        vm.expectRevert(bytes("Must have CAPITAL_MANAGEMENT_ROLE to add strategy"));
        _vault.addStrategy(address(_steth));
        vm.stopPrank();

        // whitelisting our capital management user
        vm.startPrank(_userAdmin);
        _vault.grantRole(CAPITAL_MANAGEMENT_ROLE, userCapitalManagement);
        vm.stopPrank();

        // Now checking the event
        // First time working with expectEmit so I'll be commenting a lot for future reference
        // https://book.getfoundry.sh/cheatcodes/expect-emit?highlight=expectEmitted#examples
        // function expectEmit(
        //     bool checkTopic1,
        //     bool checkTopic2,
        //     bool checkTopic3,
        //     bool checkData,
        //     address emitter
        // ) external;
        vm.expectEmit(true, false, false, false, address(_vault));
        // We emit the event we expect to see.
        emit StrategyAdded(address(_steth));
        // emit MyToken.Transfer(true, address(_vault));

        // finally adding the new strategy
        vm.startPrank(userCapitalManagement);
        _vault.addStrategy(address(_steth));
        vm.stopPrank();
    }

    function testStrategies() public {
        // setup our deposit user
        address userCapitalManagement = vm.addr(0x201);
        // give 100 eth
        vm.deal(userCapitalManagement, 100 ether);

        // check that the strategies array is empty
        assertEq(_vault.strategies().length, 0);

        // whitelisting our capital management user
        vm.startPrank(_userAdmin);
        _vault.grantRole(CAPITAL_MANAGEMENT_ROLE, userCapitalManagement);
        vm.stopPrank();

        // add Strategy
        vm.startPrank(userCapitalManagement);
        _vault.addStrategy(address(_steth));
        vm.stopPrank();

        // check that the strategies array lenghth is now 1
        assertEq(_vault.strategies().length, 1);
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
