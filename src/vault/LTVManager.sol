// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IVault} from "../interfaces/IVault.sol";

contract LTVManager {
    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

}
