// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./Strategy.sol";

/**
 * @title StrategyCreator
 * @dev Factory contract for creating new Strategy instances using the minimal proxy pattern
 */
contract StrategyCreator {
    /// @notice The address of the implementation contract that will be cloned
    address immutable implementation;

    /// @notice Struct containing strategy parameters
    struct Strategy {
        /// @dev The collateral token address for this strategy
        address collateralToken;
        /// @dev The market ID this strategy is associated with
        uint256 market;
        /// @dev The fee charged for cover
        uint256 coverFee;
        /// @dev The capacity multiplier for this strategy
        uint256 capacityMultiplier;
    }

    /// @notice Mapping from strategy address to its parameters
    mapping(address => Strategy) public strategies;

    /**
     * @dev Constructor sets the implementation contract address
     * @param _implementation Address of the Strategy implementation contract
     */
    constructor(address _implementation) {
        implementation = _implementation;
    }
    
    /**
     * @dev Creates a new Strategy clone
     * @return Address of the newly created Strategy clone
     */
    function createStrategy(address _collateralAsset, uint256 _market, uint256 _coverFee) external returns (address) {
        // Deploy a new strategy with cover token
        address clone = Clones.clone(implementation);

        // Store strategy parameters
        strategies[clone] = Strategy({
            collateralToken: _collateralAsset,
            market: _market,
            coverFee: _coverFee
        });

        return clone;
    }
}