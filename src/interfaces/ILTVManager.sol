// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ILTVManager {
    function vault() external view returns (address);
    function calculateETHLTV() external view returns (uint256);
    function calculateLRTLTV(address lrt) external view returns (uint256);
}