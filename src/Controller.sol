// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "./interfaces/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract Controller {

    using SafeERC20 for IERC20;

    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;

    /// @notice The network middleware contract instance
    INetworkMiddleware public immutable networkMiddleware;

    /// @notice Mapping from base asset (ETH/LRT) to its cover token instance
    mapping(address => address) public coverTokens;

    /// @notice The oracle contract instance
    address public immutable oracle;

    error NotOracle();
    error NoCoverTokenForAsset();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);

    modifier onlyOracle() {
        if (msg.sender != oracle) revert NotOracle();
        _;
    }

    constructor(
        address _networkMiddleware,
        address _coverTokenFactory,
        address _oracle
    ) {
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        oracle = _oracle;
    }

    /**
     * @notice Deposits tokens directly into a vault
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
        // Create vault if it doesn't exist, otherwise deposit directly
        if (!networkMiddleware.isAuthorizedVault(vault)) {
            (vault,,) = networkMiddleware.createAndAuthorizeVault(
                token,
                7 days, // Default epoch duration
                address(this) // This contract as admin
            );
        }

        // Deposit tokens directly to vault
        IVault(vault).deposit(onBehalfOf, amount);
    }

    /**
     * @notice Allows users to buy cover tokens directly from the contract
     * @notice Price discovery is yet to be implemented!
     * @param token The address of the underlying token for which cover is needed
     * @param vault The address of the vault to buy cover from
     * @param amount The amount of cover tokens to buy
     * @dev User must approve this contract to spend their tokens
     */
    function buyCover(address token, address vault, uint256 amount) external {
        // Get or create cover token for this asset
        address coverToken = coverTokens[token];
        if (coverToken == address(0)) {
            coverToken = coverTokenFactory.createCoverToken(token);
            coverTokens[token] = coverToken;
            // Initialize the cover token with this contract as owner
            ICoverToken(coverToken).initialize(
                address(this),
                token, // eETH
                string(abi.encodePacked("Ray ", IERC20Metadata(token).name())), // Ray eETH
                string(abi.encodePacked("r", IERC20Metadata(token).symbol())) // reETH
            );
        }

        // Calculate amount of cover tokens that can be minted based on Capacity
        uint256 maxCoverTokenAmount = _calculateCapacity(token, vault);
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        // Transfer tokens from user to this contract
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        // Mint cover tokens directly to the buyer
        ICoverToken(coverToken).mint(msg.sender, token, amount);
    }

    /**
     * @notice Initiates a withdrawal request from a vault directly
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
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Initiate withdrawal directly from vault
        IVault(vault).withdraw(onBehalfOf, amount);
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
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Calculate amount of cover tokens to burn based on Capacity
        uint256 coverTokenAmount = _calculateCapacity(vault, token);

        // Burn cover tokens from the recipient
        ICoverToken(coverToken).burn(recipient, coverTokenAmount);

        // Claim tokens directly from vault
        IVault(vault).claim(recipient, epoch);
    }


    //@dev Internal function to calculate the capacity of the Vault
    //@param token - the token address
    //@param vault - the vault address
    function _calculateCapacity(address token, address vault) internal view returns (uint256) {
        // Get the vault balance directly
        uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, token);
        /** 
         * @dev 90% of the token balance is used to calculate the amount
         * of cover tokens that can be minted, this could be adjusted
         * based on the python simulations
         */
        uint256 capacity = (tokenBalance * 90) / 100;
        return capacity;
    }
}
