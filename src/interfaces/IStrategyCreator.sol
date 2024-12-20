// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategyCreator {
    /// @notice Struct containing strategy parameters
    struct Strategy {
        /// @dev The collateral token address for this strategy
        address collateralToken;
        /// @dev The market ID this strategy is associated with
        uint256 market;
        /// @dev The fee charged for cover
        uint256 coverFee;
    }

    /// @notice Creates a new Strategy clone
    /// @param _collateralToken The collateral token address for the strategy
    /// @param _market The market ID this strategy is associated with
    /// @param _coverFee The fee charged for cover
    /// @return Address of the newly created Strategy clone
    function createStrategy(
        address _collateralToken,
        uint256 _market,
        uint256 _coverFee
    ) external returns (address);

    /// @notice Returns the strategy parameters for a given strategy address
    /// @param strategy The strategy address to query
    /// @return The Strategy struct containing the parameters
    function strategies(address strategy) external view returns (Strategy memory);
}