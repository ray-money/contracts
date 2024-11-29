// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ILTVManager} from "./interfaces/ILTVManager.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {IDeposit} from "./interfaces/IDeposit.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";

contract Controller {
    /// @notice The deposit contract instance
    IDeposit public immutable deposit;
    
    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;
    
    /// @notice Mapping from base asset (ETH/LRT) to its cover token instance
    mapping(address => address) public coverTokens;

    constructor(
        address _deposit,
        address _coverTokenFactory,
        address _networkMiddleware
    ) {
        deposit = IDeposit(_deposit);
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
    }
}