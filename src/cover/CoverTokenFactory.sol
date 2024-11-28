// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./CoverToken.sol";

contract CoverTokenFactory {
    address immutable implementation;
    
    constructor(address _implementation) {
        implementation = _implementation;
    }
    
    function createCoverToken(
        address owner,
        address ltvManager,
        string memory name,
        string memory symbol
    ) external returns (address) {
        address clone = Clones.clone(implementation);
        CoverToken(clone).initialize(owner, ltvManager, name, symbol);
        return clone;
    }
}