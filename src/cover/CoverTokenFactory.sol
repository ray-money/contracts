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
     * @dev Creates a new CoverToken clone and initializes it
     * @param owner The owner address for the new CoverToken
     * @param ltvManager The LTVManager contract address
     * @param baseAsset The base asset of the cover token, 0x if ETH or LRT address otherwise
     * @param name The name for the new CoverToken
     * @param symbol The symbol for the new CoverToken
     * @return Address of the newly created CoverToken clone
     */
    function createCoverToken(
        address owner,
        address ltvManager,
        address baseAsset,
        string memory name,
        string memory symbol
    ) external returns (address) {
        // Create minimal proxy clone of the implementation
        address clone = Clones.clone(implementation);
        // Initialize the cloned contract
        CoverToken(clone).initialize(owner, ltvManager, baseAsset, name, symbol);
        return clone;
    }
}