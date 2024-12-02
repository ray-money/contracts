// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ILTVManager} from "./interfaces/ILTVManager.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";

contract Controller {

    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;

    /// @notice The network middleware contract instance
    INetworkMiddleware public immutable networkMiddleware;

    /// @notice The LTV manager contract instance
    ILTVManager public immutable ltvManager;

    /// @notice Mapping from base asset (ETH/LRT) to its cover token instance
    mapping(address => address) public coverTokens;

    constructor(
        address _networkMiddleware,
        address _coverTokenFactory
    ) {
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
    }

    /**
     * @notice Deposits tokens into a vault through the network middleware and mints cover tokens
     * @param vault The address of the vault to deposit to
     * @param token The address of the token being deposited
     * @param amount The amount of tokens to deposit
     * @param onBehalfOf The address to credit the deposit and cover tokens to
     */
    function deposit(
        address vault,
        address token,
        uint256 amount,
        address onBehalfOf
    ) external {
        // Deposit tokens to vault through middleware
        networkMiddleware.depositToVault(vault, amount, onBehalfOf);

        // Get or create cover token for this asset
        address coverToken = coverTokens[token];
        if (coverToken == address(0)) {
            coverToken = coverTokenFactory.createCoverToken(token);
            coverTokens[token] = coverToken;
            // Initialize the cover token with this contract as owner
            ICoverToken(coverToken).initialize(
                address(this),
                address(ltvManager),
                token,
                string(abi.encodePacked("Cover ", IERC20(token).name())),
                string(abi.encodePacked("c", IERC20(token).symbol()))
            );
        }

        // Calculate amount of cover tokens to mint based on LTV
        uint256 coverTokenAmount = ltvManager.calculateLTV(token);

        // Mint cover tokens to the depositor
        ICoverToken(coverToken).mint(onBehalfOf, coverTokenAmount);
    }
}