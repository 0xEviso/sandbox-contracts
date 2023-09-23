// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICurvePool1 {
    function get_p() external view returns (uint256);

    function get_dy(
        int128 from,
        int128 to,
        uint256 from_amount
    ) external view returns (uint256);
}

interface ICurvePool2 {
    function get_p() external view returns (uint256);

    function get_dy(
        uint256 from,
        uint256 to,
        uint256 from_amount
    ) external view returns (uint256);
}
