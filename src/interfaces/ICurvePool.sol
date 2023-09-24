// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurvePool1 {
    function get_p() external view returns (uint256);

    function get_dy(
        int128 from,
        int128 to,
        uint256 from_amount
    ) external view returns (uint256);

    function exchange(
        int128 from,
        int128 to,
        uint256 from_amount,
        uint256 min_to_amount
    ) external payable returns (uint256 amount);
}

interface ICurvePool2 {
    function get_p() external view returns (uint256);

    function get_dy(
        uint256 from,
        uint256 to,
        uint256 from_amount
    ) external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    // Exchange using WETH by default
    function exchange(
        uint256 from,
        uint256 to,
        uint256 from_amount,
        uint256 min_to_amount
    ) external payable returns (uint256 amount);

    // Exchange using ETH by default
    function exchange_underlying(
        uint256 from,
        uint256 to,
        uint256 from_amount,
        uint256 min_to_amount
    ) external payable returns (uint256 amount);
}
