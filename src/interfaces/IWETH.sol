// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";

interface IWETH is IERC20 {
    event Deposit(address indexed dst, uint256 wad);
    event Withdrawal(address indexed src, uint256 wad);

    fallback() external payable;

    receive() external payable;

    function deposit() external payable;

    function withdraw(uint256 wad) external;
}
