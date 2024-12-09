// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./CoverToken.sol";

/**
 * @title CoverTokenFactory
 * @dev Factory contract for creating new CoverToken instances using the minimal proxy pattern
 */
contract CoverTokenFactory {
    /// @notice The address of the implementation contract that will be cloned
    address immutable implementation;
    
    /**
     * @dev Constructor sets the implementation contract address
     * @param _implementation Address of the CoverToken implementation contract
     */
    constructor(address _implementation) {
        implementation = _implementation;
    }
    
    /**
     * @dev Creates a new CoverToken clone
     * @param baseAsset The base asset of the cover token
     * @return Address of the newly created CoverToken clone
     */
    function createCoverToken(address baseAsset) external returns (address) {
        // Create minimal proxy clone of the implementation
        address clone = Clones.clone(implementation);
        return clone;
    }
}