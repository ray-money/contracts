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

    /// @notice Set of covered assets
    EnumerableSet.AddressSet private coveredAssets;

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
        address _collateralAsset,
        uint48 _epochDuration,
        address _defaultAdmin,
        address[] memory _coveredAssets
    ) {
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        keeper = _keeper;

        // Create vault through middleware
        (address _vault, , ) = networkMiddleware.createAndAuthorizeVault(
            _collateralAsset,
            _epochDuration,
            _defaultAdmin
        );

        // Store vault
        vault = _vault;

        // Store covered assets
        for (uint256 i = 0; i < _coveredAssets.length; i++) {
            coveredAssets.add(_coveredAssets[i]);
        }

        // Create cover tokens for each covered asset and store them in idToCoverToken
        for (uint256 i = 0; i < _coveredAssets.length; i++) {
            address asset = _coveredAssets[i];
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
     * @param coverTokenID The ID of the underlying token for which cover is needed
     * @param amount The amount of cover tokens to buy
     * @dev User must approve this contract to spend their tokens
     */
    function buyCover(uint256 coverTokenID, uint256 amount) external {
        address coverToken = idToCoverToken[coverTokenID];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        // Calculate amount of cover tokens that can be minted based on Capacity
        uint256 maxCoverTokenAmount = _calculateCapacity();
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        // Mint cover tokens directly to the buyer
        ICoverToken(coverToken).mint(msg.sender, amount);
    }

    //@notice: placeholder function, the logic will be updated in the future
    //@dev Internal function to calculate the capacity of the Vault
    function _calculateCapacity() internal view returns (uint256) {
        // Get the vault balance
        uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, address(this));
        
        // Get number of covered assets
        uint256 numCoveredAssets = coveredAssets.length();

        // Calculate total supply of all cover tokens
        uint256 totalCoverTokenSupply;
        for (uint256 i = 0; i < numCoveredAssets; i++) {
            address asset = coveredAssets.at(i);
            address coverToken = idToCoverToken[i];
            if (coverToken != address(0)) {
                totalCoverTokenSupply += IERC20(coverToken).totalSupply();
            }
        }
        // Calculate capacity by multiplying balance by number of covered assets
        uint256 capacity = (tokenBalance * numCoveredAssets) - totalCoverTokenSupply;
        
        return capacity;
    }
}
