// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

interface IsfrxETH is IERC20 {
    function convertToShares(uint256 assets) external view returns (uint256);
}
