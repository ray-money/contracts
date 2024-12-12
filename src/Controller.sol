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

    /// @notice The vault address
    address public vault;

    /// @notice Set of supported assets for coverage
    EnumerableSet.AddressSet private supportedAssets;

    /// @notice Mapping from covered asset to cover token address
    mapping(address => address) public coveredAssetToCoverToken;

    /// @notice The keeper contract instance
    address public immutable keeper;

    bool public initialized;

    error NotKeeper();
    error AlreadyInitialized();
    error NoCoverTokenForAsset();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    constructor(
        address _networkMiddleware,
        address _coverTokenFactory,
        address _keeper
    ) {
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        keeper = _keeper;

    }

    function initialize(
        address _baseAsset,
        uint48 _epochDuration,
        address _defaultAdmin,
        address[] memory _supportedAssets
    ) external {
        if (initialized) revert AlreadyInitialized();

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

        // Create cover tokens for each supported asset and store them in coveredAssetToCoverToken
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
            // Store the mapping of asset to cover token address
            coveredAssetToCoverToken[asset] = coverToken;
        }

        initialized = true;
    }

    /**
     * @notice Allows users to buy cover tokens directly from the contract
     * @notice Price discovery is yet to be implemented!
     * @param coveredAsset The address of the underlying token for which cover is needed
     * @param amount The amount of cover tokens to buy
     * @dev User must approve this contract to spend their tokens
     */
    function buyCover(address coveredAsset, uint256 amount) external {
        address coverToken = coveredAssetToCoverToken[coveredAsset];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Calculate amount of cover tokens that can be minted based on Capacity
        uint256 maxCoverTokenAmount = _calculateCapacity();
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        // Mint cover tokens directly to the buyer
        ICoverToken(coverToken).mint(msg.sender, amount);
    }

    /**
     * @notice Allows the keeper to slash validators through the network middleware
     * @param validator The address of the validator to slash
     * @param amount The amount to slash
     * @param timestamp The timestamp of the slashing event
     * @dev Only callable by keeper
     */
    function executeSlash(
        address validator,
        uint256 amount,
        uint48 timestamp
    ) external onlyKeeper {
        networkMiddleware.slash(
            vault,
            validator,
            amount,
            timestamp
        );
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
            address coverToken = coveredAssetToCoverToken[asset];
            if (coverToken != address(0)) {
                totalCoverTokenSupply += IERC20(coverToken).totalSupply();
            }
        }
        // Calculate capacity by multiplying balance by number of supported assets
        uint256 capacity = (tokenBalance * numSupportedAssets) - totalCoverTokenSupply;

        return capacity;
    }
}
