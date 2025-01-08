// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {
    ERR_AUTH,
    ERR_CLAIM_NOT_PAYABLE
} from "../Errors.sol";


interface ClaimOracleLike {
    // Returns true if the claim is payable, false otherwise.
    // If true, the second return value is the percentage of cover that is payable, scaled 1e18.
    function claimPayable() external returns (bool, uint256);
}

interface SlashQueueLike {
    function queueSlash(address _capacityLedger) external;
}

/// @notice Keeps track of markets, and their claim oracle and capacity token.
/// Anyone can create a market, but only the markets that created coverage matter.
contract Markets {
    /*//////////////////////////////////////////////////////////////
                                 Data Structures
    //////////////////////////////////////////////////////////////*/

    struct Market {
        /// @dev Oracle for deciding if the claim is valid.
        /// This decision is then used to determine if insurees
        /// should be paid by liquidity providers and how much.
        address claimOracle;

        // Ledger for tracking capacity allocation
        // Offers a per-block enumeration of capacity allocators and their allocation
        // so they can be identified and slashed.
        address capacityLedger;

        // Ledger for tracking cover
        address coverLedger;

        // Takes the sum of cover and capacity values to get utilization,
        // gives the price for the cover in terms of APY of the cover value.  
        address feePricer;

        // Admin for the market. 
        // The zero address by default and immutable after market gets created.
        // Non-zero means the market is controlled by an admin.
        address admin;
    }

    /*//////////////////////////////////////////////////////////////
                                 States
    //////////////////////////////////////////////////////////////*/

    address slashQueue;

    address admin;

    uint256 public marketCount;

    mapping(uint256 => Market) public markets;

    /*//////////////////////////////////////////////////////////////
                                Public interface
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, address _slashQueue) {
        admin = _admin;
        slashQueue = _slashQueue;
    }

    event MarketCreated(
        uint256 indexed marketID,
        address indexed claimOracle,
        address coverLedger,
        address capacityLedger,
        address feePricer 
    ); 

    /// @notice Creates a market permissionlessly.
    function createMarket(
        address _claimOracle,
        address _capacityLedger,
        address _coverLedger,
        address _feePricer,
        address _admin
    ) external {
        markets[marketCount++] = Market({
            claimOracle: _claimOracle,
            coverLedger: _coverLedger,
            capacityLedger: _capacityLedger,
            feePricer: _feePricer,
            admin: _admin
        });
    }

    function operateMarket(uint8 _op, uint256 _marketID, bytes calldata _input) external {
        if (msg.sender != markets[_marketID].admin) revert ERR_AUTH();

        (address _addr) = abi.decode(_input, (address));
        if (_op == 1) {
            markets[_marketID].claimOracle = _addr;
        } else if (_op == 2) {
            markets[_marketID].coverLedger = _addr;
        } else if (_op == 3) {
            markets[_marketID].capacityLedger = _addr;
        } else if (_op == 4) {
            markets[_marketID].feePricer = _addr;
        } else if (_op == 5) {
            markets[_marketID].admin = _addr;
        }
    }

    function changeSlashQueue(address _slashQueue) external {
        if (msg.sender != admin) revert ERR_AUTH();
        slashQueue = _slashQueue;
    }

    function queueSlash(uint256 _marketID) external {
        (bool _claimPayable, uint256 _claimPayablePercentage) = ClaimOracleLike(markets[_marketID].claimOracle).claimPayable();
        if (!_claimPayable || _claimPayablePercentage == 0) revert ERR_CLAIM_NOT_PAYABLE(_marketID);
        SlashQueueLike(slashQueue).queueSlash(markets[_marketID].capacityLedger);
    }
}