// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Vault {
    // a list of whitelisted lsts
    address[] public lsts;
    
    constructor(address[] memory _lsts) {
        lsts = _lsts;
    }
    // Mapping to track user deposits
    mapping(address => uint256) public lps;

    // deposit ETH to the vault
    function depositETH(uint256 amount) public payable {
        require(msg.value == amount, "Amount mismatch");
        lps[msg.sender] += amount;
    }

    // Prevent direct ETH transfers
    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }
    // Prevent direct ETH transfers with fallback
    fallback() external payable {
        revert("Direct ETH transfers not allowed"); 
    }
}
