// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICoverTokenFactory {
    function createCoverToken(
        address owner,
        address ltvManager,
        address baseAsset,
        string memory name,
        string memory symbol
    ) external returns (address);
}