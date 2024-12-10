// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/core/src/interfaces/IVaultConfigurator.sol";

contract MockVaultConfigurator is IVaultConfigurator {
    function VAULT_FACTORY() external pure override returns (address) {
        return address(0x1);
    }

    function DELEGATOR_FACTORY() external pure override returns (address) {
        return address(0x2);
    }

    function SLASHER_FACTORY() external pure override returns (address) {
        return address(0x3);
    }

    function create(InitParams calldata /* params */) external pure override returns (
        address vault,
        address delegator,
        address slasher
    ) {
        return (address(0x4), address(0x5), address(0x6));
    }
}