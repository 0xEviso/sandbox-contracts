// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC4626} from "@openzeppelin/interfaces/IERC4626.sol";
import {IAccessControlEnumerable} from "@openzeppelin/access/IAccessControlEnumerable.sol";

interface IVault is IERC4626, IAccessControlEnumerable {
    function pauseCapital() external;
    function unpauseCapital() external;
}
