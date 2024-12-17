// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Keeps track of markets, and their claim oracle and capacity token.
/// Anyone can create a market, but only the market that created coverage matter.
contract Markets {
    /*//////////////////////////////////////////////////////////////
                                 Data Structures
    //////////////////////////////////////////////////////////////*/

    struct Market {
        /// @dev Oracle for deciding if the claim is valid.
        /// This decision is then used to determine if insurees
        /// should be paid by liquidity providers and how much.
        address claimOracle;

        // Ledger for tracking capacity provisioning
        address capacityToken;
    }

    /*//////////////////////////////////////////////////////////////
                                 States
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Market) public markets;

    uint256 public marketCount;

    /*//////////////////////////////////////////////////////////////
                                Public interface
    //////////////////////////////////////////////////////////////*/

    event MarketCreated(address indexed claimOracle, address indexed capacityToken); 

    /// @notice Creates a market permissionlessly.
    function createMarket(address _claimOracle, address _capacityToken) external {
        markets[marketCount++] = Market({
            claimOracle: _claimOracle,
            capacityToken: _capacityToken
        });
        emit MarketCreated(_claimOracle, _capacityToken);
    }
}