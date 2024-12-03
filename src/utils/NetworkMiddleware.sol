// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

/** 
 * @notice INetworkRegistry - Manages the registration and tracking of networks in the system
 * Handles network onboarding, verification, and maintenance of network status
 */
import {INetworkRegistry} from "lib/core/src/interfaces/INetworkRegistry.sol";

/** 
 * @notice INetworkMiddlewareService - Acts as an intermediary service layer between different components
 * Handles communication and coordination between various network parts
 * Manages middleware settings and configurations
 */
import {INetworkMiddlewareService} from "lib/core/src/interfaces/service/INetworkMiddlewareService.sol";

/** 
 * @notice IVault - Manages the storage and handling of staked assets
 * Responsible for deposit/withdrawal functionality
 * Ensures secure custody of tokens or assets
 */
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";

/** 
 * @notice IVaultConfigurator - Handles vault configuration and setup
 * Responsible for creating and initializing new vaults with specified parameters
 * Manages vault deployment with associated delegator and slasher contracts
 */
import {IVaultConfigurator} from "lib/core/src/interfaces/IVaultConfigurator.sol";

/** 
 * @notice ISlasher - Handles punishment mechanisms for malicious or misbehaving validators/operators
 * @notice IVetoSlasher - Provides mechanism to prevent or override slashing actions for governance/safety
 */
import {ISlasher} from "lib/core/src/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "lib/core/src/interfaces/slasher/IVetoSlasher.sol";

/** 
 * @notice INetworkRestakeDelegator - Manages the delegation of staked assets
 * Handles restaking mechanism where staked assets can be redirected or re-delegated
 * Part of liquid staking/delegation system
 */
import {INetworkRestakeDelegator} from "lib/core/src/interfaces/delegator/INetworkRestakeDelegator.sol";

//@notice IDefaultStakerRewards - Defines how rewards are distributed to users who stake assets
//@notice IDefaultOperatorRewards - Defines how rewards are distributed to operators/validators
import {IDefaultStakerRewards} from "lib/rewards/src/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


contract Network {
    constructor(
        INetworkRegistry networkRegistry,
        INetworkMiddlewareService middlewareService
    ) {
        networkRegistry.registerNetwork();
        middlewareService.setMiddleware(msg.sender);
    }
}

contract NetworkMiddleware is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice VaultConfigurator reference
    IVaultConfigurator public immutable vaultConfigurator;
    /// @notice Burner address
    address public burner;

    /// @notice Registry contract for managing network registration and status
    INetworkRegistry public immutable networkRegistry;
    
    /// @notice Service contract for coordinating network middleware functionality
    INetworkMiddlewareService public immutable middlewareService;

    error UnauthorizedVault(address vault);
    error VaultAlreadyAuthorized(address vault);
    error VaultNotAuthorized(address vault);
    error InvalidBurnerAddress(address burner);

    event NetworkDeployed(address network);
    event VaultAuthorized(address vault);
    event VaultDeauthorized(address vault);

    /// @notice Set of authorized vaults
    EnumerableSet.AddressSet private vaults;

    /// @notice Contract for managing operator reward distributions
    IDefaultOperatorRewards public operatorRewards;

    /// @notice Initializes the middleware contract
    /// @param _operatorRewards Address of the operator rewards contract
    constructor(
        IDefaultOperatorRewards _operatorRewards,
        VaultConfigurator _vaultConfigurator,
        address _burner
    ) Ownable(msg.sender) {
        if (_burner == address(0)) revert InvalidBurnerAddress(_burner);
        operatorRewards = _operatorRewards;
        vaultConfigurator = _vaultConfigurator;
        burner = _burner;
    }

    /**
     * @notice Modifier to restrict access to authorized vaults only
     * @param vault The address of the vault to check authorization for
     * @dev Reverts with UnauthorizedVault if the vault is not in the authorized vaults set
     */
    modifier onlyAuthorized(address vault) {
        if (!vaults.contains(vault)) revert UnauthorizedVault(vault);
        _;
    }

    /**
     * @notice Creates and authorizes a new vault using VaultConfigurator
     * @param collateral The collateral token address
     * @param epochDuration The epoch duration
     * @param defaultAdmin The default admin address
     * @return vault The address of the created vault
     * @return delegator The address of the created delegator
     * @return slasher The address of the created slasher
     */
    function createAndAuthorizeVault(
        address collateral,
        uint48 epochDuration,
        address defaultAdmin
    ) external onlyOwner returns (
        address vault,
        address delegator,
        address slasher
    ) {
        // Encode vault initialization parameters
        bytes memory vaultParams = abi.encode(
            Vault.InitParams({
                collateral: collateral,
                burner: burner,
                epochDuration: epochDuration,
                depositWhitelist: false,
                isDepositLimit: false,
                depositLimit: 0,
                defaultAdminRoleHolder: defaultAdmin,
                depositWhitelistSetRoleHolder: defaultAdmin,
                depositorWhitelistRoleHolder: defaultAdmin,
                isDepositLimitSetRoleHolder: defaultAdmin,
                depositLimitSetRoleHolder: defaultAdmin
            })
        );

        // Create vault using VaultConfigurator
        (vault, delegator, slasher) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: 1, //TODO; add versioning system
                owner: address(this), //TODO; confirm owner, maybe pass Controller as owner
                vaultParams: vaultParams,
                delegatorIndex: 0, // Use appropriate index
                delegatorParams: "", // Add delegator params if needed
                withSlasher: true,
                slasherIndex: 0, // Use appropriate index
                slasherParams: "" // Add slasher params if needed
            })
        );

        // Add to authorized vaults
        if (!vaults.add(vault)) {
            revert VaultAlreadyAuthorized(vault);
        }

        emit VaultAuthorized(vault);
    }

    /**
     * @notice Updates the burner address
     * @param _burner The new burner address
     */
    function updateBurner(address _burner) external onlyOwner {
        if (_burner == address(0)) revert InvalidBurnerAddress(_burner);
        burner = _burner;
        emit BurnerUpdated(_burner);
    }

    /**
     * @notice Removes a vault from the set of authorized vaults
     * @param vault The address of the vault to deauthorize
     * @dev Only callable by contract owner
     * @dev Reverts with VaultNotAuthorized if vault is not currently authorized
     */
    function deauthorizeVault(address vault) external onlyOwner {
        if (!vaults.contains(vault)) {
            revert VaultNotAuthorized(vault);
        }

        vaults.remove(vault);
        emit VaultDeauthorized(vault);
    }

    /**
     * @notice Deploys a new Network contract instance
     * @return network The address of the newly deployed Network contract
     * @dev Creates new Network with networkRegistry and middlewareService
     */
    function deployNetwork() external returns (address network) {
        network = address(new Network(networkRegistry, middlewareService));
        emit NetworkDeployed(network);
    }

    /**
    * @notice Gets the active balance of an account in a vault
    * @param vault The vault address
    * @param account The account to check
    * @return The active balance
    */
    function getVaultActiveBalance(
        address vault,
        address account
    ) external view onlyAuthorized(vault) returns (uint256) {
        return IVault(vault).activeBalanceOf(account);
    }

    /**
     * @notice Allocates stake to a validator through a vault
     * @param vault The vault address to allocate stake through
     * @param validator The validator address to allocate stake to
     * @param amount The amount of stake to allocate
     * @dev Only callable by owner and for authorized vaults
     */
    function allocateStake(
        address vault,
        address validator,
        uint256 amount
    ) external onlyOwner onlyAuthorized(vault) {
        INetworkRestakeDelegator(IVault(vault).delegator())
            .setOperatorNetworkShares(
                bytes32(bytes20(address(this))),  // Using this contract's address instead
                validator,
                amount
            );
    }

    /**
     * @notice Slashes a validator's stake through a vault
     * @param vault The vault address to slash through
     * @param validator The validator address to slash
     * @param amount The amount to slash
     * @param timestamp The timestamp of the slashing event
     * @dev Only callable by owner and for authorized vaults
     */
    function slash(
        address vault,
        address validator,
        uint256 amount,
        uint48 timestamp
    ) external onlyOwner onlyAuthorized(vault) {
        bytes32 network = bytes32(bytes20(address(this)));
        ISlasher(IVault(vault).slasher()).slash(
            network,
            validator,
            amount,
            timestamp,
            new bytes(0)
        );
    }

    /**
     * @notice Distributes rewards to stakers through the staker rewards contract
     * @param stakerRewards The staker rewards contract to distribute through
     * @param token The token address to distribute as rewards
     * @param amount The amount of tokens to distribute
     * @dev Only callable by owner and for authorized vaults
     */
    function rewardStakers(
        IDefaultStakerRewards stakerRewards,
        address token,
        uint256 amount
    ) external onlyOwner onlyAuthorized(stakerRewards.VAULT()) {
        address network = address(this);
        stakerRewards.distributeRewards(network, token, amount, bytes(""));
    }

    /**
     * @notice Distributes rewards to operators
     * @param token The token address to distribute as rewards
     * @param amount The amount of tokens to distribute
     * @param root The merkle root for reward distribution
     * @dev Only callable by owner
     */
    function rewardOperators(
        address token,
        uint256 amount,
        bytes32 root
    ) external onlyOwner {
        address network = address(this);
        operatorRewards.distributeRewards(network, token, amount, root);
    }
}