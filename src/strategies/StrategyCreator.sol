// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts/contracts/proxy/Clones.sol";
import "./Strategy.sol";
import "../interfaces/IStrategyCreator.sol";

/**
 * @title StrategyCreator
 * @notice Factory contract for creating new Strategy instances using the minimal proxy pattern
 */
contract StrategyCreator is IStrategyCreator {
    // Custom errors
    error InvalidImplementation();
    error InvalidCollateralToken();

    /// @notice The address of the implementation contract that will be cloned
    address public immutable implementation;

    /// @notice Mapping from strategy address to its parameters 
    mapping(address => Strategy) public strategies;

    /// @notice Emitted when a new strategy is created
    event StrategyCreated(address indexed strategy, address indexed collateralToken, uint256 market);

    /**
     * @notice Constructor sets the implementation contract address
     * @param _implementation Address of the Strategy implementation contract
     */
    constructor(address _implementation) {
        if (_implementation == address(0)) revert InvalidImplementation();
        implementation = _implementation;
    }

    /**
     * @notice Creates a new Strategy clone
     * @param _collateralToken The collateral token address for the strategy
     * @param _market The market ID this strategy is associated with
     * @param _coverFee The fee charged for cover
     * @return clone Address of the newly created Strategy clone
     */
    function createStrategy(
        address _collateralToken,
        uint256 _market,
        uint256 _coverFee,
        uint256 _capacityMultiplier
    ) external returns (address) {
        if (_collateralToken == address(0)) revert InvalidCollateralToken();
        
        // Deploy a new strategy clone
        address clone = Clones.clone(implementation);

        // Store strategy parameters
        strategies[clone] = Strategy({
            collateralToken: _collateralToken,
            market: _market,
            coverFee: _coverFee,
            capacityMultiplier: _capacityMultiplier
        });

        emit StrategyCreated(clone, _collateralToken, _market);

        return clone;
    }
}