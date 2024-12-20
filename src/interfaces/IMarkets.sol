// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IMarkets
/// @notice Interface for Markets contract that manages insurance markets and their components
interface IMarkets {
    /// @notice Represents a single insurance market with its core components
    struct Market {
        /// @notice Oracle that validates insurance claims for this market
        address claimOracle;

        /// @notice Token used to track insurance capacity in this market
        address capacityToken;
    }

    /// @notice Emitted when a new market is created
    /// @param claimOracle The oracle address for validating claims
    /// @param capacityToken The token address for tracking capacity
    event MarketCreated(address indexed claimOracle, address indexed capacityToken);

    /// @notice Creates a new insurance market
    /// @param _claimOracle The oracle that will validate claims for this market
    /// @param _capacityToken The token that will track insurance capacity
    /// @dev Anyone can create a market permissionlessly
    function createMarket(address _claimOracle, address _capacityToken) external;

    /// @notice Retrieves information about a specific market
    /// @param marketId The unique identifier of the market
    /// @return Market details including claim oracle and capacity token addresses
    function markets(uint256 marketId) external view returns (Market memory);

    /// @notice Returns the total number of markets that have been created
    /// @return The current count of all markets
    function marketCount() external view returns (uint256);
}
