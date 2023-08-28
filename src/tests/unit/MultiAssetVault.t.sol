// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {MultiAssetVault} from "../../contracts/MultiAssetVault.sol";

import {WETH} from "../mocks/WETH.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import "forge-std/console.sol";

contract MultiAssetVaultTest is Test {
    // Vault related variables
    MultiAssetVault internal _vault;
    // Event to be emitted when a new strategy is added
    event StrategyAdded(address strategy);
    // Event to be emitted when a strategy is revoked
    event StrategyRevoked(address strategy);

    // eth mainnet weth
    WETH internal _weth =
        WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    // eth mainnet wsteth
    MockERC20 internal _wsteth;
    // IERC20 internal _wsteth = IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    // eth mainnet reth
    MockERC20 internal _reth;
    // IERC20 internal _reth = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    // eth mainnet sfrxeth
    MockERC20 internal _sfrxeth;
    // IERC20 internal _sfrxeth = IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F);

    // exchange rate taken from 1inch on Aug 25th 2023
    uint256 public constant WSTETH_PRICE_WAD = 1.1367339865949497 * 1e18;
    uint256 public constant RETH_PRICE_WAD = 1.084770261579532 * 1e18;
    uint256 public constant SFRXETH_PRICE_WAD = 1.052379930535395 * 1e18;

    // Money management role
    bytes32 public constant CAPITAL_MANAGEMENT_ROLE =
        keccak256("CAPITAL_MANAGEMENT_ROLE");
    // emergency deposit freeze, emergency strategy liquidation...
    bytes32 public constant EMERGENCY_FREEZE_ROLE =
        keccak256("EMERGENCY_FREEZE_ROLE");
    // Needs to be white-listed to deposit capital
    bytes32 public constant DEPOSIT_WHITELIST_ROLE =
        keccak256("DEPOSIT_WHITELIST_ROLE");

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
        _vault = new MultiAssetVault(_weth, "YieldNestETH", "ynETH");
        _wsteth = new MockERC20("Wrapped Staked Ether", "WSTETH", 18);
        _reth = new MockERC20("Rocket Pool ETH", "RETH", 18);
        _sfrxeth = new MockERC20("Staked FRAX ETH", "SFRXETH", 18);
        vm.stopPrank();
    }

    function testInit() public {
        assertEq(_vault.name(), "YieldNestETH");
        assertEq(_vault.symbol(), "ynETH");
        assertEq(_vault.decimals(), 18);
        assertEq(
            address(_vault.asset()),
            0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2
        );
        assertEq(_vault.totalAssets(), 0);
    }

    // function testWhitelisting() public {
    //     // setup our deposit user
    //     address userDeposit = vm.addr(0x200);
    //     // give 100 eth
    //     vm.deal(userDeposit, 100 ether);
    //     // swap 10 eth for weth
    //     vm.startPrank(userDeposit);
    //     _weth.deposit{value: 10 ether}();
    //     vm.stopPrank();

    //     // non whitelisted user should not be able to deposit
    //     vm.startPrank(userDeposit);
    //     _weth.approve(address(_vault), 10e18);
    //     vm.expectRevert(bytes("Must have DEPOSIT_WHITELIST_ROLE to deposit"));
    //     _vault.deposit(1 ether, address(userDeposit));
    //     vm.stopPrank();

    //     // whitelisting our deposit user
    //     vm.startPrank(_userAdmin);
    //     _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
    //     vm.stopPrank();

    //     // whitelisted user should be able to deposit
    //     vm.startPrank(userDeposit);
    //     _weth.approve(address(_vault), 10e18);
    //     _vault.deposit(1 ether, address(userDeposit));
    //     vm.stopPrank();
    // }

    // function testDeposit() public {
    //     // setup our deposit user
    //     address userDeposit = vm.addr(0x200);
    //     // give 100 eth
    //     vm.deal(userDeposit, 100 ether);
    //     // swap 10 eth for weth
    //     vm.startPrank(userDeposit);
    //     _weth.deposit{value: 10 ether}();
    //     vm.stopPrank();
    //     // whitelisting our deposit user
    //     vm.startPrank(_userAdmin);
    //     _vault.grantRole(DEPOSIT_WHITELIST_ROLE, userDeposit);
    //     vm.stopPrank();

    //     // checks that deposit user funds in the vaults are 0
    //     assertEq(_vault.totalAssets(), 0);
    //     assertEq(_vault.balanceOf(userDeposit), 0);

    //     // deposit
    //     vm.startPrank(userDeposit);
    //     _weth.approve(address(_vault), 1 ether);
    //     _vault.deposit(1 ether, address(userDeposit));
    //     vm.stopPrank();

    //     // checks that deposit user funds in the vaults are 1 eth equivalent
    //     assertEq(_vault.totalAssets(), 1 ether);
    //     assertEq(_vault.balanceOf(userDeposit), 1 ether);
    // }

    function testAddStrategy() public {
        // setup our management user
        address userCapitalManagement = vm.addr(0x201);
        // give 100 eth
        vm.deal(userCapitalManagement, 100 ether);

        // only user with CAPITAL_MANAGEMENT_ROLE ca call the function
        vm.startPrank(userCapitalManagement);
        vm.expectRevert(
            bytes("Must have CAPITAL_MANAGEMENT_ROLE to add strategy")
        );
        // add strategy
        _vault.addStrategy(address(_wsteth), WSTETH_PRICE_WAD);
        vm.stopPrank();

        // whitelisting our capital management user
        vm.startPrank(_userAdmin);
        _vault.grantRole(CAPITAL_MANAGEMENT_ROLE, userCapitalManagement);
        vm.stopPrank();

        // Now checking the event
        // First time working with expectEmit so I'll be commenting a lot
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
        emit StrategyAdded(address(_wsteth));
        // finally adding the new strategy
        vm.startPrank(userCapitalManagement);
        // add strategy
        _vault.addStrategy(address(_wsteth), WSTETH_PRICE_WAD);
        vm.stopPrank();
    }

    function testStrategies() public {
        // setup our management user
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
        // add strategy
        _vault.addStrategy(address(_wsteth), WSTETH_PRICE_WAD);
        vm.stopPrank();

        // check that the strategies array lenghth is now 1
        assertEq(_vault.strategies().length, 1);
        // check that the single strategy getter function works
        assertEq(
            _vault.getStrategy(address(_wsteth)).activatedAt,
            block.number
        );
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

        // setup our management user
        address userCapitalManagement = vm.addr(0x201);
        // give 100 eth
        vm.deal(userCapitalManagement, 100 ether);
        // whitelisting our capital management user
        vm.startPrank(_userAdmin);
        _vault.grantRole(CAPITAL_MANAGEMENT_ROLE, userCapitalManagement);
        vm.stopPrank();

        // add 3 strategies
        vm.startPrank(userCapitalManagement);
        // add Strategies
        _vault.addStrategy(address(_wsteth), WSTETH_PRICE_WAD);
        _vault.addStrategy(address(_reth), RETH_PRICE_WAD);
        _vault.addStrategy(address(_sfrxeth), SFRXETH_PRICE_WAD);
        vm.stopPrank();

        // get lowest allocation > lowest or first 0 (wseth)
        assertEq(_vault.getLowestStrategyAllocation(), address(_wsteth));

        uint256 depositAmount = 0;
        uint256 wethEquivalent = 0;

        // try deposit 2 wsteth
        depositAmount = 2e18;
        _wsteth.mint(userDeposit, depositAmount);
        vm.startPrank(userDeposit);
        _wsteth.approve(address(_vault), depositAmount);
        _vault.deposit(address(_wsteth), depositAmount, address(userDeposit));
        vm.stopPrank();

        // check vault assets (assets are priced in weth equivalent)
        wethEquivalent += (depositAmount * WSTETH_PRICE_WAD) / 1e18;
        assertEq(_vault.totalAssets(), wethEquivalent);
        // check user shares (if vault was empty shares = assets)
        assertEq(_vault.balanceOf(userDeposit), wethEquivalent);
        // check vault wsteth allocation (priced in strategy token directly)
        assertEq(_vault.getStrategy(address(_wsteth)).totalDebt, depositAmount);
        // get lowest allocation > lowest or first 0 (reth)
        assertEq(_vault.getLowestStrategyAllocation(), address(_reth));

        // try deposit 2 wsteth again (this time should fail)
        depositAmount = 2e18;
        _wsteth.mint(userDeposit, depositAmount);
        vm.startPrank(userDeposit);
        _wsteth.approve(address(_vault), depositAmount);
        // allocation check > no pass (not lowest allocation)
        vm.expectRevert(bytes("Must deposit strategy with lowest allocation"));
        _vault.deposit(address(_wsteth), depositAmount, address(userDeposit));
        vm.stopPrank();

        // try deposit 3 reth
        depositAmount = 3e18;
        _reth.mint(userDeposit, depositAmount);
        vm.startPrank(userDeposit);
        _reth.approve(address(_vault), depositAmount);
        _vault.deposit(address(_reth), depositAmount, address(userDeposit));
        vm.stopPrank();

        // check vault assets (assets are priced in weth equivalent)
        wethEquivalent += (depositAmount * RETH_PRICE_WAD) / 1e18;
        assertEq(_vault.totalAssets(), wethEquivalent);
        // check user shares (if vault was empty shares = assets)
        assertEq(_vault.balanceOf(userDeposit), wethEquivalent);
        // check vault wsteth allocation (priced in strategy token directly)
        assertEq(_vault.getStrategy(address(_reth)).totalDebt, depositAmount);
        // get lowest allocation > lowest or first 0 (reth)
        assertEq(_vault.getLowestStrategyAllocation(), address(_sfrxeth));

        // try deposit 4 sfrxeth
        depositAmount = 4e18;
        _sfrxeth.mint(userDeposit, depositAmount);
        vm.startPrank(userDeposit);
        _sfrxeth.approve(address(_vault), depositAmount);
        _vault.deposit(address(_sfrxeth), depositAmount, address(userDeposit));
        vm.stopPrank();

        // check vault assets (assets are priced in weth equivalent)
        wethEquivalent += (depositAmount * SFRXETH_PRICE_WAD) / 1e18;
        assertEq(_vault.totalAssets(), wethEquivalent);
        // check user shares (if vault was empty shares = assets)
        assertEq(_vault.balanceOf(userDeposit), wethEquivalent);
        // check vault wsteth allocation (priced in strategy token directly)
        assertEq(
            _vault.getStrategy(address(_sfrxeth)).totalDebt,
            depositAmount
        );
        // get lowest allocation > lowest (steth)
        assertEq(_vault.getLowestStrategyAllocation(), address(_wsteth));

        // By the point every strategy has some allocation
        // we are now going to trying to add more allocation to steth
        // and check that get lowest allocation works and we're done

        // try deposit 2 wsteth
        depositAmount = 2e18;
        _wsteth.mint(userDeposit, depositAmount);
        vm.startPrank(userDeposit);
        _wsteth.approve(address(_vault), depositAmount);
        _vault.deposit(address(_wsteth), depositAmount, address(userDeposit));
        vm.stopPrank();

        // check vault assets (assets are priced in weth equivalent)
        wethEquivalent += (depositAmount * WSTETH_PRICE_WAD) / 1e18;
        assertEq(_vault.totalAssets(), wethEquivalent);
        // check user shares (if vault was empty shares = assets)
        assertEq(_vault.balanceOf(userDeposit), wethEquivalent);
        // check vault wsteth allocation (priced in strategy token directly)
        // * 2 because we've already deposited 2 wsteth earlier
        assertEq(
            _vault.getStrategy(address(_wsteth)).totalDebt,
            depositAmount * 2
        );
        // get lowest allocation > lowest (now _reth)
        assertEq(_vault.getLowestStrategyAllocation(), address(_reth));
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
