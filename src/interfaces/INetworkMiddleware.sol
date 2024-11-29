// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {INetworkRegistry} from "lib/core/src/interfaces/INetworkRegistry.sol";
import {INetworkMiddlewareService} from "lib/core/src/interfaces/service/INetworkMiddlewareService.sol";
import {IDefaultStakerRewards} from "lib/rewards/src/interfaces/defaultStakerRewards/IDefaultStakerRewards.sol";
import {IDefaultOperatorRewards} from "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";

interface INetworkMiddleware {
    error UnauthorizedVault(address vault);
    error VaultAlreadyAuthorized(address vault);
    error VaultNotAuthorized(address vault);

    event NetworkDeployed(address network);
    event VaultAuthorized(address vault);
    event VaultDeauthorized(address vault);

    function networkRegistry() external view returns (INetworkRegistry);
    function middlewareService() external view returns (INetworkMiddlewareService);
    function operatorRewards() external view returns (IDefaultOperatorRewards);

    function deployNetwork() external returns (address);
    function authorizeVault(address vault) external;
    function deauthorizeVault(address vault) external;
    function isAuthorizedVault(address vault) external view returns (bool);
    function getAuthorizedVaults() external view returns (address[] memory);
    
    function slash(
        address vault,
        address validator,
        uint256 amount,
        uint48 timestamp
    ) external;

    function rewardStakers(
        IDefaultStakerRewards stakerRewards,
        address token,
        uint256 amount
    ) external;

    function rewardOperators(
        address token,
        uint256 amount,
        bytes32 root
    ) external;
}
