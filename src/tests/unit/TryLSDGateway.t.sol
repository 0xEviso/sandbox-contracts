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
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    // Event to be emitted when a user deposits through the Gateway
    event Deposit(
        address indexed sender,
        address indexed owner,
        uint256 ethAmount,
        uint256 shares,
        uint256 stethAmount,
        uint256 rethAmount,
        uint256 frxethAmount
    );

    /*//////////////////////////////////////////////////////////////
                    VARIABLES & EXTERNAL CONTRACTS
    //////////////////////////////////////////////////////////////*/

    // Gateway variable
    TryLSDGateway internal _gateway;

    // curve tryLSD mainnet pool
    ICurvePool2 internal _tryLSD =
        ICurvePool2(0x2570f1bD5D2735314FC102eb12Fc1aFe9e6E7193);

    /*//////////////////////////////////////////////////////////////
                                SET UP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        _gateway = new TryLSDGateway();
    }

    /*//////////////////////////////////////////////////////////////
                            CONTRACT TESTS
    //////////////////////////////////////////////////////////////*/

    function testDeposit() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // deposit 10 eth to the gateway

        assertEq(_tryLSD.balanceOf(userDeposit), 0);

        // Prepare to check deposit event
        vm.expectEmit(true, true, false, false, address(_gateway));
        // We emit the event we expect to see.
        emit Deposit(userDeposit, userDeposit, 0, 0, 0, 0, 0);

        vm.startPrank(userDeposit);
        // calculate amounts for the swap after, these values will be used for slippage
        // todo swap amount calculation should include amount of pool shares as well
        (
            uint256 stethAmount,
            uint256 rethAmount,
            uint256 frxethAmount
        ) = _gateway.calculateSwapAmounts(10 ether);

        // deposit 10 eth to the gateway
        _gateway.swapAndDeposit{value: 10 ether}(
            userDeposit,
            (stethAmount * 999) / 1000, // 0.1% slippage
            (rethAmount * 999) / 1000, // 0.1% slippage
            (frxethAmount * 999) / 1000 // 0.1% slippage
        );
        vm.stopPrank();

        // check that the pool shares were minted
        assertGt(_tryLSD.balanceOf(userDeposit), 3e18);
    }
}
