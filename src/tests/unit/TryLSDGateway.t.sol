// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

import {TryLSDGateway} from "../../contracts/TryLSDGateway.sol";
import {ICurvePool2} from "../../interfaces/ICurvePool.sol";

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
    ICurvePool2 internal _tryLSD =
        ICurvePool2(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193);

    function setUp() public {
        _gateway = new TryLSDGateway(
            address(_tryLSD),
            address(_wsteth),
            address(_reth),
            address(_sfrxeth)
        );
    }

    function testDeposit() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // deposit 10 eth to the gateway

        assertEq(_tryLSD.balanceOf(userDeposit), 0);

        console.log("_tryLSD balance:", _tryLSD.balanceOf(userDeposit));

        vm.startPrank(userDeposit);
        // calculate amounts for the swap after, these values will be used for slippage
        (
            uint256 stethAmount,
            uint256 rethAmount,
            uint256 frxethAmount
        ) = _gateway.calculateSwapAmounts(30 ether);

        _gateway.swapAndDeposit{value: 30 ether}(
            userDeposit,
            (stethAmount * 999) / 1000, // 0.1% slippage
            (rethAmount * 999) / 1000, // 0.1% slippage
            (frxethAmount * 999) / 1000 // 0.1% slippage
        );
        vm.stopPrank();

        console.log("_tryLSD balance:", _tryLSD.balanceOf(userDeposit));

        // check for deposit event

        // check that the user has pool lp tokens
    }
}
