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
        uint256 shares
    );

    event Withdraw(
        address indexed sender,
        address indexed receiver,
        address indexed owner,
        uint256 ethAmount,
        uint256 shares
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
        emit Deposit(userDeposit, userDeposit, 0, 0);

        // estimate amount of shares user should get, for slippage
        uint256 calculatedShares = _gateway.calculatePoolShares(10 ether);
        // 0.1% slippage
        uint256 minShares = (calculatedShares * 999) / 1000;

        // deposit 10 eth to the gateway
        vm.prank(userDeposit);
        uint256 shares = _gateway.swapAndDeposit{value: 10 ether}(
            userDeposit,
            minShares
        );

        // quick slippage check
        assertGt(shares, minShares);
        // check that the pool shares were minted
        assertEq(_tryLSD.balanceOf(userDeposit), shares);
        // check the pool shares amount
        assertGt(_tryLSD.balanceOf(userDeposit), 3e18);
    }

    function testWithdraw() public {
        // setup our deposit user
        address userDeposit = vm.addr(0x200);
        address userEthReceiver = vm.addr(0x201);
        // give 100 eth
        vm.deal(userDeposit, 100 ether);
        // deposit 10 eth to the gateway
        // estimate amount of shares user should get, for slippage
        uint256 calculatedShares = _gateway.calculatePoolShares(10 ether);
        // 0.1% slippage
        uint256 minShares = (calculatedShares * 999) / 1000;
        // deposit 10 eth to the gateway
        vm.prank(userDeposit);
        uint256 shares = _gateway.swapAndDeposit{value: 10 ether}(
            userDeposit,
            minShares
        );

        // todo try withdraw more than shares
        // todo try withdraw 0 shares

        // calculate amount of eth that user should receive
        uint256 calculatedEth = _gateway.calculateEth(shares);
        // 0.1% slippage
        uint256 minEth = (calculatedEth * 999) / 1000;

        // Prepare to check deposit event
        vm.expectEmit(true, true, true, false, address(_gateway));
        // We emit the event we expect to see.
        emit Withdraw(userDeposit, userEthReceiver, userDeposit, 0, 0);

        // withdraw
        vm.prank(userDeposit);
        uint256 ethReceived = _gateway.swapAndWithdraw(
            userEthReceiver,
            shares,
            minEth
        );
        // quick slippage check
        assertGt(ethReceived, minEth);
        // check that the eth was sent
        assertEq(userEthReceiver.balance, ethReceived);
        // check eth amount
        assertGt(userEthReceiver.balance, 3e18);
    }
}
