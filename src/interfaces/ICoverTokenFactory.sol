// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICoverTokenFactory {
    function createCoverToken() external returns (address);
}