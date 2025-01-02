// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

contract Ledger {
    // TODO: implement
    address montroller;

    constructor(address _montroller) {
        montroller = _montroller;
    }

    // msg.sender could be a strategist/power user or regular user
    // As long as Capacity Registry acknowledges the update, it is valid
    // keccak256(msg.sender, _prefix) gives the 
    function setCapacity(uint256 _prefix, uint256 _capacity) external {
    }
}
