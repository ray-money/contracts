// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";

contract Markets {
    /*//////////////////////////////////////////////////////////////
                                 Data Structures
    //////////////////////////////////////////////////////////////*/

    struct Market {
        address coverToken;
        address claimOracle;
        address allocationToken;
    }

    /*//////////////////////////////////////////////////////////////
                                 States
    //////////////////////////////////////////////////////////////*/

    mapping(uint256 => Market) public markets;

    uint256 public marketCount;

    address public immutable coverTokenFactory;


    /*//////////////////////////////////////////////////////////////
                                 Events
    //////////////////////////////////////////////////////////////*/
    event MarketCreated(address indexed coverToken, address indexed claimOracle, address indexed allocationToken); 

    /*//////////////////////////////////////////////////////////////
                                Public interface
    //////////////////////////////////////////////////////////////*/

    constructor(address _coverTokenFactory) {
        coverTokenFactory = _coverTokenFactory;
    }

    /// @notice Creates a market from a claim oracle
    /// @notice A market is identified by a fungible and transferrable cover token
    /// and a claim oracle. When a claim is made, the claim oracle decides how
    /// much of the coverage that the cover tokens represent is eligible for claim.
    /// E.g. There is 100 cover tokens representing 100 wstETH of coverage, 30% is claimable.
    function createMarket(address _claimOracle, address _allocationToken) external returns (address _coverToken) {
        _coverToken = ICoverTokenFactory(coverTokenFactory).createCoverToken();
        markets[marketCount++] = Market({
            claimOracle: _claimOracle,
            coverToken: _coverToken,
            allocationToken: _allocationToken
        });
        emit MarketCreated(_coverToken, _claimOracle, _allocationToken);
    }
}
