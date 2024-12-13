// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {INetworkRegistry} from "lib/core/src/interfaces/INetworkRegistry.sol";
import {INetworkMiddlewareService} from "lib/core/src/interfaces/service/INetworkMiddlewareService.sol";
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";
import {IVaultConfigurator} from "lib/core/src/interfaces/IVaultConfigurator.sol";
import {ISlasher} from "lib/core/src/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "lib/core/src/interfaces/slasher/IVetoSlasher.sol";
import {INetworkRestakeDelegator} from "lib/core/src/interfaces/delegator/INetworkRestakeDelegator.sol";
import {IDefaultStakerRewards} from "lib/rewards/src/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title Network
 * @notice Simple contract for registering networks and setting middleware
 */
contract Network {
    constructor(
        INetworkRegistry networkRegistry,
        INetworkMiddlewareService middlewareService
    ) {
        networkRegistry.registerNetwork();
        middlewareService.setMiddleware(msg.sender);
    }
}

/**
 * @title NetworkMiddleware
 * @notice Manages network operations including vault management, staking, slashing and rewards
 * @dev Acts as intermediary between network components and core functionality
 */
contract NetworkMiddleware is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    // ============ Storage ============

    IVaultConfigurator public immutable vaultConfigurator;
    INetworkRegistry public immutable networkRegistry;
    INetworkMiddlewareService public immutable middlewareService;
    IDefaultOperatorRewards public operatorRewards;
    
    address public burner;
    address public network;
    EnumerableSet.AddressSet private vaults;

    // ============ Events ============

    event NetworkDeployed(address network);
    event VaultAuthorized(address vault);
    event VaultDeauthorized(address vault);
    event BurnerUpdated(address burner);

    // ============ Errors ============

    error UnauthorizedVault(address vault);
    error VaultAlreadyAuthorized(address vault);
    error VaultNotAuthorized(address vault);
    error InvalidBurnerAddress(address burner);

    // ============ Constructor ============

    constructor(
        IDefaultOperatorRewards _operatorRewards,
        IVaultConfigurator _vaultConfigurator,
        address _burner
    ) Ownable(msg.sender) {
        if (_burner == address(0)) revert InvalidBurnerAddress(_burner);
        operatorRewards = _operatorRewards;
        vaultConfigurator = _vaultConfigurator;
        burner = _burner;
    }

    // ============ Modifiers ============

    modifier onlyAuthorized(address vault) {
        if (!vaults.contains(vault)) revert UnauthorizedVault(vault);
        _;
    }

    // ============ External Functions ============

    function createAndAuthorizeVault(
        address collateral,
        uint48 epochDuration,
        address defaultAdmin
    ) external onlyOwner returns (
        address vault,
        address delegator,
        address slasher
    ) {
        bytes memory vaultParams = _encodeVaultParams(collateral, epochDuration, defaultAdmin);

        (vault, delegator, slasher) = vaultConfigurator.create(
            IVaultConfigurator.InitParams({
                version: 1,
                owner: address(this),
                vaultParams: vaultParams,
                delegatorIndex: 0,
                delegatorParams: "",
                withSlasher: true,
                slasherIndex: 0,
                slasherParams: ""
            })
        );

        if (!vaults.add(vault)) {
            revert VaultAlreadyAuthorized(vault);
        }

        emit VaultAuthorized(vault);

        return (vault, delegator, slasher);
    }

    function updateBurner(address _burner) external onlyOwner {
        if (_burner == address(0)) revert InvalidBurnerAddress(_burner);
        burner = _burner;
        emit BurnerUpdated(_burner);
    }

    function deauthorizeVault(address vault) external onlyOwner {
        if (!vaults.contains(vault)) {
            revert VaultNotAuthorized(vault);
        }

        vaults.remove(vault);
        emit VaultDeauthorized(vault);
    }

    function deployNetwork() external returns (address) {
        network = address(new Network(networkRegistry, middlewareService));
        emit NetworkDeployed(network);
        return network;
    }

    function getVaultActiveBalance(
        address vault,
        address account
    ) external view onlyAuthorized(vault) returns (uint256) {
        return IVault(vault).activeBalanceOf(account);
    }

    function allocateStake(
        address vault,
        address operator,
        uint256 amount
    ) external onlyOwner onlyAuthorized(vault) {
        INetworkRestakeDelegator(IVault(vault).delegator())
            .setOperatorNetworkShares(
                bytes32(bytes20(address(this))),
                operator,
                amount
            );
    }

    function slash(
        address vault,
        address operator,
        uint256 amount,
        uint48 timestamp
    ) external onlyOwner onlyAuthorized(vault) {
        bytes32 networkId = bytes32(bytes20(network));
        ISlasher(IVault(vault).slasher()).slash(
            networkId,
            operator,
            amount,
            timestamp,
            new bytes(0)
        );
    }

    function rewardStakers(
        IDefaultStakerRewards stakerRewards,
        address token,
        uint256 amount
    ) external onlyOwner onlyAuthorized(stakerRewards.VAULT()) {
        stakerRewards.distributeRewards(network, token, amount, bytes(""));
    }

    function rewardOperators(
        address token,
        uint256 amount,
        bytes32 root
    ) external onlyOwner {
        operatorRewards.distributeRewards(network, token, amount, root);
    }

    // ============ Internal Functions ============

    function _encodeVaultParams(
        address collateral,
        uint48 epochDuration,
        address defaultAdmin
    ) internal view returns (bytes memory) {
        return abi.encode(
            collateral,
            burner,
            epochDuration,
            false, // depositWhitelist
            false, // isDepositLimit
            0, // depositLimit
            defaultAdmin, // defaultAdminRoleHolder
            defaultAdmin, // depositWhitelistSetRoleHolder
            defaultAdmin, // depositorWhitelistRoleHolder
            defaultAdmin, // isDepositLimitSetRoleHolder
            defaultAdmin  // depositLimitSetRoleHolder
        );
    }
}