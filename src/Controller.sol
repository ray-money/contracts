// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {INetworkMiddleware} from "./interfaces/INetworkMiddleware.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "./interfaces/IERC20Metadata.sol";
import {SafeERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Controller
 * @notice Main contract for managing cover tokens and coverage claims
 * @dev Handles cover token creation, buying coverage, and claim processing
 */
contract Controller {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============ Storage ============

    ICoverTokenFactory public immutable coverTokenFactory;
    INetworkMiddleware public immutable networkMiddleware;
    address public immutable keeper;
    address public vault;
    address public collateralAsset;
    bool public initialized;

    EnumerableSet.AddressSet private supportedAssets;
    mapping(address => address) public coveredAssetToCoverToken;

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
        address _coverTokenFactory,
        address _networkMiddleware,
        address _keeper
    ) {
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
        keeper = _keeper;
    }

    // ============ External Functions ============

    function initialize(
        address _collateralAsset,
        uint48 _epochDuration,
        address _defaultAdmin,
        address[] memory _supportedAssets
    ) external whenNotInitialized {
        collateralAsset = _collateralAsset;

        (address _vault, , ) = networkMiddleware.createAndAuthorizeVault(
            _collateralAsset,
            _epochDuration,
            _defaultAdmin
        );
        vault = _vault;

        _setupSupportedAssets(_supportedAssets);
        _createCoverTokens(_supportedAssets);

        initialized = true;
        emit Initialized(_vault, _collateralAsset);
    }

    function buyCover(address coveredAsset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        address coverToken = coveredAssetToCoverToken[coveredAsset];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        uint256 maxCoverTokenAmount = _calculateCapacity();
        if (amount > maxCoverTokenAmount) revert AmountExceedsCapacity(amount, maxCoverTokenAmount);

        IERC20(coveredAsset).transferFrom(msg.sender, address(this), amount);
        ICoverToken(coverToken).mint(msg.sender, amount);
        emit CoverBought(msg.sender, coveredAsset, amount);
    }

    function claimCover(address coveredAsset, uint256 amount) external {
        if (amount == 0) revert InvalidAmount();

        address coverToken = coveredAssetToCoverToken[coveredAsset];
        if (coverToken == address(0)) revert NoCoverTokenForAsset();

        ICoverToken(coverToken).burn(msg.sender, amount);

        IERC20(collateralAsset).transfer(msg.sender, amount);

        emit CoverageClaimed(msg.sender, coveredAsset, amount);
    }
//////////////////////////////// WIP ////////////////////////////////
    struct RebaseShares {
        uint256 totalBuyerShares;
        uint256 totalLpShares;
    }

    mapping(address => uint256) public buyerShares;
    mapping(address => uint256) public lpShares;
    RebaseShares public rebaseShares;
    mapping(address => uint256) public accumulatedLpRewards;
    uint256 private constant MINIMUM_REWARD_THRESHOLD = 1e18; // 1 token minimum threshold
    uint256 private constant BUYER_SHARE_PERCENTAGE = 80;

    event RebaseCalculated(
        address indexed asset,
        uint256 buyerShare,
        uint256 lpShare,
        uint256 excessAmount
    );

    function calculateRebase() external onlyKeeper {
        uint256 numSupportedAssets = supportedAssets.length();
        
        for (uint256 i = 0; i < numSupportedAssets; i++) {
            address coveredAsset = supportedAssets.at(i);
            address coverToken = coveredAssetToCoverToken[coveredAsset];
            
            if (coverToken == address(0)) continue;

            uint256 currentBalance = IERC20(coveredAsset).balanceOf(address(this));
            uint256 coverTokenSupply = IERC20(coverToken).totalSupply();

            if (currentBalance <= coverTokenSupply) continue;

            uint256 excessAmount = currentBalance - coverTokenSupply;
            uint256 buyerShare = (excessAmount * BUYER_SHARE_PERCENTAGE) / 100;
            uint256 lpShare = excessAmount - buyerShare;

            buyerShares[coveredAsset] = buyerShare;
            lpShares[coveredAsset] = lpShare;
            rebaseShares.totalBuyerShares += buyerShare;
            rebaseShares.totalLpShares += lpShare;
            accumulatedLpRewards[coveredAsset] += lpShare;

            if (accumulatedLpRewards[coveredAsset] >= MINIMUM_REWARD_THRESHOLD) {
                _distributeRewards(coveredAsset);
            }

            emit RebaseCalculated(coveredAsset, buyerShare, lpShare, excessAmount);
        }
    }

    function _distributeRewards(address coveredAsset) internal {
        bytes32 merkleRoot = _generateMerkleRoot(
            coveredAsset,
            accumulatedLpRewards[coveredAsset]
        );
        
        networkMiddleware.rewardOperators(
            coveredAsset,
            accumulatedLpRewards[coveredAsset],
            merkleRoot
        );

        accumulatedLpRewards[coveredAsset] = 0;
    }

    function _generateMerkleRoot(
        address asset,
        uint256 totalRewards
    ) internal view returns (bytes32) {
        uint256 numSupportedAssets = supportedAssets.length();
        uint256 totalStake;
        
        // Calculate total stake
        for (uint256 i = 0; i < numSupportedAssets; i++) {
            address operator = supportedAssets.at(i);
            totalStake += networkMiddleware.getVaultActiveBalance(vault, operator);
        }

        if (totalStake == 0) return bytes32(0);

        // Build merkle tree leaves
        bytes32[] memory leaves = new bytes32[](numSupportedAssets);
        for (uint256 i = 0; i < numSupportedAssets; i++) {
            address operator = supportedAssets.at(i);
            uint256 operatorStake = networkMiddleware.getVaultActiveBalance(vault, operator);
            uint256 operatorRewards = (totalRewards * operatorStake) / totalStake;
            leaves[i] = keccak256(abi.encodePacked(operator, operatorRewards));
        }

        return _buildMerkleRoot(leaves);
    }

    function _buildMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];

        while (leaves.length > 1) {
            if (leaves.length % 2 == 1) {
                bytes32[] memory newLeaves = new bytes32[](leaves.length + 1);
                for (uint256 i = 0; i < leaves.length; i++) {
                    newLeaves[i] = leaves[i];
                }
                newLeaves[leaves.length] = leaves[leaves.length - 1];
                leaves = newLeaves;
            }

            bytes32[] memory newLeaves = new bytes32[](leaves.length / 2);
            for (uint256 i = 0; i < leaves.length; i += 2) {
                newLeaves[i/2] = _hashPair(leaves[i], leaves[i + 1]);
            }
            leaves = newLeaves;
        }

        return leaves[0];
    }

    function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : keccak256(abi.encodePacked(b, a));
    }
//////////////////////////////////////////////////////////////////////


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

    function _epochAt(uint48 timestamp) internal view returns (uint256) {
        return IVault(vault).epochAt(timestamp);
    }

    function _calculateCapacity() internal view returns (uint256) {
        uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, address(this));
        uint256 numSupportedAssets = supportedAssets.length();

        uint256 totalCoverTokenSupply;
        for (uint256 i = 0; i < numSupportedAssets; i++) {
            address asset = supportedAssets.at(i);
            address coverToken = coveredAssetToCoverToken[asset];
            if (coverToken != address(0)) {
                totalCoverTokenSupply += IERC20(coverToken).totalSupply();
            }
        }

        return (tokenBalance * numSupportedAssets) - totalCoverTokenSupply;
    }

    function _setupSupportedAssets(address[] memory _supportedAssets) internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            supportedAssets.add(_supportedAssets[i]);
        }
    }

    function _createCoverTokens(address[] memory _supportedAssets) internal {
        for (uint256 i = 0; i < _supportedAssets.length; i++) {
            address asset = _supportedAssets[i];
            address coverToken = coverTokenFactory.createCoverToken();

            ICoverToken(coverToken).initialize(
                address(this),
                asset,
                string(abi.encodePacked("Ray ", IERC20Metadata(asset).name())),
                string(abi.encodePacked("r", IERC20Metadata(asset).symbol()))
            );

            coveredAssetToCoverToken[asset] = coverToken;
        }
    }
}
