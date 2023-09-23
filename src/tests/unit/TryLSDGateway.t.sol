// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {TryLSDGateway} from "../../contracts/TryLSDGateway.sol";
import {ICurveTryLSD} from "../../interfaces/ICurveTryLSD.sol";

import {WETH} from "../mocks/WETH.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

import "forge-std/console.sol";

contract TryLSDGatewayTest is Test {
    // Event to be emitted when a user deposits through the Gateway
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );
    // Event to be emitted when a user withdraws through the Gateway
    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 assets,
        uint256 shares
    );

    // Gateway variable
    TryLSDGateway internal _gateway;

    // eth mainnet weth
    WETH internal _weth =
        WETH(payable(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2));
    // eth mainnet wsteth
    IERC20 internal _wsteth =
        IERC20(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    // eth mainnet reth
    IERC20 internal _reth = IERC20(0xae78736Cd615f374D3085123A210448E74Fc6393);
    // eth mainnet sfrxeth
    IERC20 internal _sfrxeth =
        IERC20(0xac3E018457B222d93114458476f3E3416Abbe38F);
    // curve tryLSD mainnet pool
    ICurveTryLSD internal _tryLSD =
        ICurveTryLSD(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193);

    // exchange rate taken from 1inch on Sep 22nd 2023 in USDC
    uint256 public constant ETH_PRICE_WAD = 1593.546485 * 1e18;
    uint256 public constant WSTETH_PRICE_WAD = 1817.92132 * 1e18;
    uint256 public constant RETH_PRICE_WAD = 1729.458999 * 1e18;
    uint256 public constant SFRXETH_PRICE_WAD = 1683.36819 * 1e18;

    function setUp() public {
        _gateway = new TryLSDGateway(
            address(_tryLSD),
            address(_wsteth),
            address(_reth),
            address(_sfrxeth)
        );
    }

    function testGetPrices() public {
        _gateway.getPrices();
    }

    function testDeposit() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // deposit 10 eth to the gateway
        vm.startPrank(userDeposit);

        uint256[3] memory amounts = _gateway.calculateSwapAmounts(30 ether);
        // _gateway.deposit{value: 10 ether}();
        vm.stopPrank();

        console.log("steth", amounts[0]);
        console.log("reth", amounts[1]);
        console.log("frxeth", amounts[2]);

        // check for deposit event

        // check that the user has pool lp tokens
    }
}
