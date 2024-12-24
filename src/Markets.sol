// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERR_AUTH} from "./Errors.sol";

// This object acts a controller for each market. 
// Firstly, it maintains this model:
// 1. cover and capacity balance
// 2. claim oracle for determining payout
// 3. the address for claim oracle, fee pricer, cover and capacity ledger
//
// Secondly, it can send these commands to control slasher, and cover and capacity ledger
// 1. when there is a risk event, queue message to Slasher for downstream 
//    objects to pull and execute slashes
// 2. update cover and capacity ledger balances
// 
// The rationale for the queue is it decouples this Markets object from the Slasher object,
// in other words, they are replaceable to each other. 

// Parts:
// Claim Oracle - only external depedency, may use a veto process
// Fee Pricer - takes utilization (which is function of cover sum and capacity sum)
// Cover Ledger - tracks cover balance
// Capacity Ledger - tracks capacity allocation balance

// Depedency diagram
// Fee Pricer ---- cover sum ----> Cover Ledger
//             \                       \
//              \                       \ (check for remaining capacity before minting)
//               \                       \
//                \                       v    
//                 \ -- capacity sum -- > Capacity Ledger 
//
// Claim Oracle (only external dependency)


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

    address immutable slasher;

    address admin;

    uint256 public marketCount;

    mapping(uint256 => Market) public markets;

    /*//////////////////////////////////////////////////////////////
                                Public interface
    //////////////////////////////////////////////////////////////*/

    constructor(address _admin, address _slasher) {
        admin = _admin;
        slasher = _slasher;
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
        if (msg.sender != markets[marketID].admin) revert ERR_AUTH;

        (address _addr) = abi.decode(_input, (address));
        if (_op == 1) {
            markets[marketID].claimOracle = _addr;
        } else if (_op == 2) {
            markets[marketID].coverLedger = _addr;
        } else if (_op == 3) {
            markets[marketID].capacityLedger = _addr;
        } else if (_op == 4) {
            markets[marketID].feePricer = _addr;
        } else if (_op == 5) {
            markets[marketID].admin = _addr;
        }
    }

    function changeSlasher(address _slasher) external {
        if (msg.sender != admin) revert ERR_AUTH;
        slasher = _slasher;
    } 
}