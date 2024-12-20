// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {IStrategyCreator} from "./interfaces/IStrategyCreator.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "./interfaces/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
// import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Controller
 * @notice Main contract for managing cover tokens and coverage claims
 * @dev Handles cover token creation, buying coverage, and claim processing
 */
contract Controller {
    using SafeERC20 for IERC20;
    // using EnumerableSet for EnumerableSet.AddressSet;

    // ============ Storage ============

    IStrategyCreator public immutable strategyCreator;
    INetworkMiddleware public immutable networkMiddleware;
    address public immutable keeper;
    // address public vault; 
    // address public collateralAsset;
    bool public initialized;

    EnumerableSet.AddressSet private supportedAssets;
    // mapping(address => address) public coveredAssetToCoverToken;

    // ============ Events ============

    event CoverBought(address indexed buyer, address indexed asset, uint256 amount);
    event CoverageClaimed(address indexed claimer, address indexed asset, uint256 amount);
    event Initialized(address vault, address collateralAsset);

    // ============ Errors ============

    error NotKeeper();
    error AlreadyInitialized();
    error NoCoverTokenForAsset();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);
    error InsufficientBalance(uint256 activeBalance, uint256 amount);
    error InvalidAmount();

    // ============ Modifiers ============

    modifier onlyKeeper() {
        if (msg.sender != keeper) revert NotKeeper();
        _;
    }

    modifier whenNotInitialized() {
        if (initialized) revert AlreadyInitialized();
        _;
    }

    // ============ Constructor ============

    constructor(
        address _strategyCreator,
        address _networkMiddleware,
        address _keeper,
        address[] memory _supportedAssets
    ) {
        strategyCreator = IStrategyCreator(_strategyCreator);
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        keeper = _keeper;

        _setupSupportedAssets(_supportedAssets);
    }

    // ============ External Functions ============


    /**
     * @notice Creates a new strategy for a collateral token
     * @param collateralAsset The collateral asset for the strategy
     * @param market The market ID this strategy is associated with
     * @param coverFee The fee charged for cover
     * @return The address of the newly created strategy
     */
    function createStrategy(
        address collateralAsset,
        address coveredAsset,
        uint256 market,
        uint256 coverFee,
        uint256 capacityMultiplier,
        uint48 epochDuration,
        address defaultAdmin
    ) external onlyKeeper returns (address) {
        // Create new strategy via factory
        address strategy = strategyCreator.createStrategy(
            collateralAsset,
            market,
            coverFee,
            capacityMultiplier
        );

        // Initialize the strategy
        string memory name = string(abi.encodePacked("Cover Token ", IERC2Metadata(coveredAsset).name()));
        string memory symbol = string(abi.encodePacked("cv", IERC2Metadata(coveredAsset).symbol()));
        
        IStrategy(strategy).initialize(
            address(this),
            address(markets),
            collateralAsset,
            name,
            symbol
        );

        (address _vault, , ) = networkMiddleware.createAndAuthorizeVault(
            collateralAsset,
            epochDuration,
            defaultAdmin
        );

        return strategy;
    }

    function buyCover(address coveredAsset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        address coverToken = coveredAssetToCoverToken[coveredAsset];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        uint256 maxCoverTokenAmount = _calculateCapacity();
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        ICoverToken(coverToken).mint(msg.sender, amount);
        emit CoverBought(msg.sender, coveredAsset, amount);
    }

    function claimCoverage(address coveredAsset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();
        
        address coverToken = coveredAssetToCoverToken[coveredAsset];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        ICoverToken(coverToken).burn(msg.sender, amount);
        IERC20(coveredAsset).transferFrom(msg.sender, address(this), amount);
        IERC20(collateralAsset).transfer(msg.sender, amount);

        emit CoverageClaimed(msg.sender, coveredAsset, amount);
    }

    function executeSlash(
        address operator,
        uint256 amount,
        uint48 timestamp
    ) external onlyKeeper {
        networkMiddleware.slash(vault, operator, amount, timestamp);
    }

    function allocateOperatorStake(
        address operator,
        uint256 amount
    ) external {
        uint256 activeBalance = networkMiddleware.getVaultActiveBalance(vault, msg.sender);
        if (activeBalance < amount) revert InsufficientBalance(activeBalance, amount);

        networkMiddleware.allocateStake(vault, operator, amount);
    }

    // ============ View Functions ============

    function getSupportedAssets() external view returns (address[] memory) {
        uint256 length = supportedAssets.length();
        address[] memory assets = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            assets[i] = supportedAssets.at(i);
        }
        return assets;
    }

    function isSupportedAsset(address asset) external view returns (bool) {
        return supportedAssets.contains(asset);
    }

    // ============ Internal Functions ============

    // function _calculateCapacity() internal view returns (uint256) {
    //     uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, address(this));
    //     uint256 numSupportedAssets = supportedAssets.length();
        
    //     uint256 totalCoverTokenSupply;
    //     for (uint256 i = 0; i < numSupportedAssets; i++) {
    //         address asset = supportedAssets.at(i);
    //         address coverToken = coveredAssetToCoverToken[asset];
    //         if (coverToken != address(0)) {
    //             totalCoverTokenSupply += IERC20(coverToken).totalSupply();
    //         }
    //     }

    //     return (tokenBalance * numSupportedAssets) - totalCoverTokenSupply;
    // }

    function _setupSupportedAssets(address[] memory _supportedAssets) internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            supportedAssets.add(_supportedAssets[i]);
        }
    }

    // function _createCoverTokens(address[] memory _supportedAssets) internal {
    //     for (uint256 i = 0; i < _supportedAssets.length; i++) {
    //         address asset = _supportedAssets[i];
    //         address coverToken = coverTokenFactory.createCoverToken();
            
    //         ICoverToken(coverToken).initialize(
    //             address(this),
    //             asset,
    //             string(abi.encodePacked("Ray ", IERC20Metadata(asset).name())),
    //             string(abi.encodePacked("r", IERC20Metadata(asset).symbol()))
    //         );
            
    //         coveredAssetToCoverToken[asset] = coverToken;
    //     }
    // }
}
