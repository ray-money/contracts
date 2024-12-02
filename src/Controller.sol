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
     * @param onBehalfOf The address to credit the deposit to
     */
    function deposit(
        address vault,
        address token,
        uint256 amount,
        address onBehalfOf
    ) external {
        // Transfer tokens from user to middleware
        IERC20(token).safeTransferFrom(msg.sender, address(networkMiddleware), amount);

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

        // Mint cover tokens to this contract instead of depositor
        ICoverToken(coverToken).mint(address(this), coverTokenAmount);
    }

    /**
     * @notice Initiates a withdrawal request from a vault through the network middleware
     * @param vault The address of the vault to withdraw from
     * @param token The address of the token being withdrawn
     * @param amount The amount of tokens to withdraw
     * @param onBehalfOf The address to debit the withdrawal from
     */
    function initiateWithdraw(
        address vault,
        address token,
        uint256 amount,
        address onBehalfOf
    ) external {
        // Get cover token for this asset
        address coverToken = coverTokens[token];
        require(coverToken != address(0), "No cover token exists for asset");

        // Initiate withdrawal from vault through middleware
        networkMiddleware.withdrawFromVault(vault, amount, onBehalfOf);
    }

    /**
     * @notice Claims withdrawn tokens from a vault and burns the associated cover tokens
     * @param vault The address of the vault to claim from
     * @param token The address of the token being claimed
     * @param recipient The address to receive the withdrawn tokens
     * @param epoch The epoch to claim from
     */
    function claimWithdrawal(
        address vault,
        address token,
        address recipient,
        uint256 epoch
    ) external {
        // Get cover token for this asset
        address coverToken = coverTokens[token];
        require(coverToken != address(0), "No cover token exists for asset");

        // Calculate amount of cover tokens to burn based on LTV
        uint256 coverTokenAmount = ltvManager.calculateLTV(token);

        // Burn cover tokens from the recipient
        ICoverToken(coverToken).burn(recipient, coverTokenAmount);

        // Claim tokens from vault through middleware
        networkMiddleware.claimFromVault(vault, recipient, epoch);
    }

}