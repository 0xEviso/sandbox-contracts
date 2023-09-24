// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";

interface IWstETH is IERC20 {
    function getStETHByWstETH(uint256) external view returns (uint256);

    function getWstETHByStETH(uint256) external view returns (uint256);

    function stEthPerToken() external view returns (uint256);

    function tokensPerStEth() external view returns (uint256);

    function wrap(uint256 stETHAmount) external returns (uint256);
}
