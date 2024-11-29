// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ILTVManager} from "./interfaces/ILTVManager.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {IVault} from "./interfaces/IVault.sol";

contract Controller {
    /// @notice The vault contract instance
    IVault public immutable vault;
    
    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;
    
    /// @notice Mapping from base asset (ETH/LRT) to its cover token instance
    mapping(address => address) public coverTokens;

    constructor(address _vault, address _coverTokenFactory) {
        vault = IVault(_vault);
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
    }
}