// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "./interfaces/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Controller {

    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;

    /// @notice The network middleware contract instance
    INetworkMiddleware public immutable networkMiddleware;

    /// @notice Mapping from base asset to its vault address
    address public vault;

    /// @notice Set of supported base assets for coverage
    EnumerableSet.AddressSet private supportedAssets;

    /// @notice Mapping from ID to cover token address
    mapping(uint256 => address) public idToCoverToken;

    /// @notice The keeper contract instance
    address public immutable keeper;

    error NotKeeper();
    error NoCoverTokenForAsset();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    constructor(
        address _networkMiddleware,
        address _coverTokenFactory,
        address _keeper,
        address _baseAsset,
        uint48 _epochDuration,
        address _defaultAdmin,
        address[] memory _supportedAssets
    ) {
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        keeper = _keeper;

        // Create vault through middleware
        (address _vault, , ) = networkMiddleware.createAndAuthorizeVault(
            _baseAsset,
            _epochDuration,
            _defaultAdmin
        );

        // Store vault
        vault = _vault;

        // Store supported assets
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            supportedAssets.add(_supportedAssets[i]);
        }

        // Create cover tokens for each supported asset and store them in idToCoverToken
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            address asset = _supportedAssets[i];
            address coverToken = coverTokenFactory.createCoverToken(asset);
            // Initialize the cover token with this contract as owner
            ICoverToken(coverToken).initialize(
                address(this),
                asset,
                string(abi.encodePacked("Ray ", IERC20Metadata(asset).name())),
                string(abi.encodePacked("r", IERC20Metadata(asset).symbol()))
            );
            // Store the mapping of ID to cover token address
            idToCoverToken[i] = coverToken;
        }
    }

    /**
     * @notice Allows users to buy cover tokens directly from the contract
     * @notice Price discovery is yet to be implemented!
     * @param baseAssetID The ID of the underlying token for which cover is needed
     * @param amount The amount of cover tokens to buy
     * @dev User must approve this contract to spend their tokens
     */
    function buyCover(uint256 baseAssetID, uint256 amount) external {
        address coverToken = idToCoverToken[baseAssetID];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Calculate amount of cover tokens that can be minted based on Capacity
        uint256 maxCoverTokenAmount = _calculateCapacity();
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        // Get the base asset from the cover token
        address baseAsset = ICoverToken(coverToken).baseAsset();

        // Transfer tokens from user to this contract
        IERC20(baseAsset).safeTransferFrom(msg.sender, address(this), amount);

        // Mint cover tokens directly to the buyer
        ICoverToken(coverToken).mint(msg.sender, amount);
    }

    /**
     * @notice Initiates a withdrawal request from a vault directly
     * @param id The ID of the token being withdrawn
     * @param amount The amount of tokens to withdraw
     * @param onBehalfOf The address to debit the withdrawal from
     */
    function initiateWithdraw(
        uint256 id,
        uint256 amount,
        address onBehalfOf
    ) external {
        // Get cover token for this asset
        address coverToken = idToCoverToken[id];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Initiate withdrawal directly from vault
        IVault(vault).withdraw(onBehalfOf, amount);
    }
    
    /**
     * @notice Claims withdrawn tokens from a vault and burns the associated cover tokens
     * @param id The ID of the token being claimed
     * @param recipient The address to receive the withdrawn tokens
     * @param epoch The epoch to claim from
     */
    function claimWithdrawal(
        uint256 id,
        address recipient,
        uint256 epoch
    ) external {
        // Get cover token for this asset
        address coverToken = idToCoverToken[id];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Calculate amount of cover tokens to burn based on Capacity
        uint256 coverTokenAmount = _calculateCapacity();

        // Burn cover tokens from the recipient
        ICoverToken(coverToken).burn(recipient, coverTokenAmount);

        // Claim tokens directly from vault
        IVault(vault).claim(recipient, epoch);
    }

    //@notice: placeholder function, the logic will be updated in the future
    //@dev Internal function to calculate the capacity of the Vault
    function _calculateCapacity() internal view returns (uint256) {
        // Get the vault balance
        uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, address(this));
        
        // Get number of supported assets
        uint256 numSupportedAssets = supportedAssets.length();

        // Calculate total supply of all cover tokens
        uint256 totalCoverTokenSupply;
        for (uint256 i = 0; i < numSupportedAssets; i++) {
            address asset = supportedAssets.at(i);
            address coverToken = idToCoverToken[i];
            if (coverToken != address(0)) {
                totalCoverTokenSupply += IERC20(coverToken).totalSupply();
            }
        }
        // Calculate capacity by multiplying balance by number of supported assets
        uint256 capacity = (tokenBalance * numSupportedAssets) - totalCoverTokenSupply;
        
        return capacity;
    }
}
