// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/rewards/src/interfaces/defaultOperatorRewards/IDefaultOperatorRewards.sol";

contract MockOperatorRewards is IDefaultOperatorRewards {
    function NETWORK_MIDDLEWARE_SERVICE() external pure override returns (address) {
        return address(0x7);
    }

    function root(address, address) external pure override returns (bytes32) {
        return bytes32(0);
    }

    function balance(address, address) external pure override returns (uint256) {
        return 0;
    }

    function claimed(address, address, address) external pure override returns (uint256) {
        return 0;
    }

    function distributeRewards(address, address, uint256, bytes32) external override {
        // Mock implementation
    }

    function claimRewards(
        address,
        address,
        address,
        uint256,
        bytes32[] calldata
    ) external pure override returns (uint256) {
        return 0;
    }
}