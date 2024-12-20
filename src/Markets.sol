// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./interfaces/INetworkMiddleware.sol";


/// @notice Keeps track of markets, and their claim oracle and capacity token.
/// Anyone can create a market, but only the market that created coverage matter.
contract Markets {
    // ============ Data Structures ============

    /// @dev Oracle for deciding if the claim is valid.
    /// This decision is then used to determine if insurees
    /// should be paid by liquidity providers and how much.

    struct Market {
        address claimOracle;
        address capacityToken;
        address[] coveredAssets;
        uint256 capacityMultiplier;
    }

    // ============ States ============

    mapping(uint256 => Market) public markets;

    uint256 public marketCount;

    // ============ Public interface ============

    event MarketCreated(address indexed claimOracle, address indexed capacityToken, uint256 capacityMultiplier); 

    /// @notice Creates a market permissionlessly.
    function createMarket(address _claimOracle, address _capacityToken, address[] calldata _coveredAssets, uint256 _capacityMultiplier) external {
        markets[marketCount++] = Market({
            claimOracle: _claimOracle,
            capacityToken: _capacityToken,
            coveredAssets: _coveredAssets,
            capacityMultiplier: _capacityMultiplier
        });
        emit MarketCreated(_claimOracle, _capacityToken, _capacityMultiplier);
    }


    function _calculateCapacity(uint256 marketId, address coveredAsset) internal view returns (uint256) {
        Market storage market = markets[marketId];
        uint256 vaultBalance = IERC20(market.capacityToken).balanceOf(vault);
        
        // Check if the covered asset is supported by this market
        bool isAssetSupported;
        for (uint256 i = 0; i < market.coveredAssets.length; i++) {
            if (market.coveredAssets[i] == coveredAsset) {
                isAssetSupported = true;
                break;
            }
        }
        require(isAssetSupported, "Asset not supported by market");

        // Calculate capacity as vault balance times multiplier
        return vaultBalance * market.capacityMultiplier;
    }

}