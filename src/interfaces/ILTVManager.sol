// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ILTVManager {
    function calculateLTV(address token) external view returns (uint256);
}