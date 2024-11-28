// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
// In your factory contract:
import "@openzeppelin/contracts/proxy/Clones.sol";
import "./CoverToken.sol";  // Add this import

contract CoverTokenFactory {
    address immutable implementation;
    
    constructor(address _implementation) {
        implementation = _implementation;
    }
    
    function createCoverToken(address owner, address ltvManager) external returns (address) {
        address clone = Clones.clone(implementation);
        CoverToken(clone).initialize(owner, ltvManager);
        return clone;
    }
}