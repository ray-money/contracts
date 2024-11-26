// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract Vault {
    // mapping of whitelisted LSTs
    mapping(address => bool) public whitelistedLsts;
    //@dev Mapping to track user deposits
    mapping(address => uint256) public lps;
    //@dev oracle address
    address public oracle;

    constructor(address[] memory _lsts, address _oracle) {
        for(uint i = 0; i < _lsts.length; i++) {
            whitelistedLsts[_lsts[i]] = true;
        }
        oracle = _oracle;
    }

    //@dev deposit ETH to the vault
    function depositETH(uint256 amount) public payable {
        require(msg.value == amount, "Amount mismatch");
        lps[msg.sender] += amount;
    }

    //@dev withdraw ETH from the vault
    function withdrawETH(uint256 amount) public {
        require(lps[msg.sender] >= amount, "Insufficient balance");
        require(address(this).balance >= amount, "Insufficient contract balance");
        
        lps[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // TODO: deposit LST from the list

    // TODO: withdraw LST from the contract

    // TODO: check the balance of ETH in the contract

    // TODO: check the balance of a speciefic LST in the contract

    //@dev Check if LST is whitelisted
    function isWhitelistedLst(address lst) public view returns (bool) {
        return whitelistedLsts[lst];
    }

    //@dev Prevent direct ETH transfers
    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    //@dev Prevent direct ETH transfers with fallback
    fallback() external payable {
        revert("Direct ETH transfers not allowed"); 
    }
}
