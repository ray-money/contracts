// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// These paths should be remapped so we aren't dependent on local paths
import {ICoverTokenFactory} from "./interfaces/ICoverTokenFactory.sol";
import {ICoverToken} from "./interfaces/ICoverToken.sol";
import {EnumerableSet} from "lib/openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

// Vault is a place e.g. Symbiotic vaults, Eigenlayer equivalent or regular ERC4626 vaults
interface VaultLike {
    function deposit(address token, uint256 amt, uint8 commTyp, bytes calldata opt) external;
    function withdraw(address token, uint256 amt) external;
}

interface CoverLike {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
}

contract Controller {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice Market
    struct Market {
        address coverToken; 
        address claimOracle;
    }

    mapping(address => Market) public markets;

    event MarketCreated(address coverToken, address claimOracle);

    /// @notice Strategy
    struct Strategy {
        uint256 strategyID;
        // Each one is a VaultLike, meant to be delegate-called by the controller
        EnumerableSet.AddressSet collateralVaults;
        // The lower tranche number or index is, the more junior it is
        // Because contributors can add tranche progressively by simply splitting
        // portion of the yield for the new senior tranche to juniors
        // Tranche is represented as a vault
        mapping(uint8 => address) trancheTokens;
        address authMod;
        uint8 trancheCnt;
    }

    mapping(uint256 => Strategy) public strategies;

    uint256 public strategyCnt;
    

    // ------------- Need review below, WIP ------------------------




    /// @notice The cover token factory contract instance
    ICoverTokenFactory public immutable coverTokenFactory;


    /// @notice The vault address
    address public vault;

    /// @notice Set of supported assets for coverage
    EnumerableSet.AddressSet public coveredAssets;

    /// @notice Mapping from covered asset to cover token address
    mapping(address => address) public coveredAssetToCoverToken;

    bool public initialized;

    error AlreadyInitialized();
    error NoCoverTokenForAsset();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);

    constructor(address _coverTokenFactory) {
        coverTokenFactory = ICoverTokenFactory(_coverTokenFactory);
    }


    /// @notice Creates a market
    /// @notice A market is defined by a claim oracle, and a fungible and transferrable cover token
    /// When a claim is made, the claim oracle decides how much of the coverage that the cover tokens
    /// represent is eligible for claim.
    /// E.g. There is 100 cover tokens representing 100 wstETH of coverage, 30% is claimable.
    function createMarket(address _claimOracle) external returns (address _coverToken) {
        _coverToken = coverTokenFactory.createCoverToken();
        markets[_coverToken] = Market({
            claimOracle: _claimOracle,
            coverToken: _coverToken
        });
        emit MarketCreated(_coverToken, _claimOracle);
    }

    // mint cover tokens
    function mintCoverTokens(address coverToken, uint256 amount) external {
    }

    // redeem cover tokens

    // Deposit to one of the accepted collateral vaults.
    // Depositor gets a mint of one of the tranche tokens, chosen by the depositor, representing a portion of the tranche.
    // The tranche tokens are ERC20s.
    // The collateral vaults are adaptors to interact with external protocols e.g. Symbiotic Vaults.
    // The controller is the owner or beneficiary of the deposits on external protocols.
    function depositAsLP(uint16 vaultID, address token, uint256 amt, uint8 commTyp, bytes calldata opt) external {
        vaults[vaultID].deposit(token, amt, commTyp, opt);

    }

    // Withdraw to Symbiotic vaults and Eigenlayer 
    function withdrawAsLP(uint16 safeID, address token, uint256 amt) external {
        vaults[vaultID].withdraw(token, amt);
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


    // //@notice: placeholder function, the logic will be updated in the future
    // //@dev Internal function to calculate the capacity of the Vault
    // function _calculateCapacity() internal view returns (uint256) {
    //     // Get the vault balance
    //     uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(vault, address(this));
        
    //     // Get number of supported assets
    //     uint256 numCoveredAssets = coveredAssets.length();

    //     // Calculate total supply of all cover tokens
    //     uint256 totalCoverTokenSupply;
    //     for (uint256 i = 0; i < numCoveredAssets; i++) {
    //         address asset = coveredAssets.at(i);
    //         address coverToken = coveredAssetToCoverToken[asset];
    //         if (coverToken != address(0)) {
    //             totalCoverTokenSupply += IERC20(coverToken).totalSupply();
    //         }
    //     }
    //     // Calculate capacity by multiplying balance by number of supported assets
    //     uint256 capacity = (tokenBalance * numCoveredAssets) - totalCoverTokenSupply;
        
    //     return capacity;
    // }
}
