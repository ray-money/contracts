// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
import {IVault} from "../interfaces/IVault.sol";

contract LTVManager {
    IVault public vault;

    constructor(address _vault) {
        vault = IVault(_vault);
    }
    //@dev Calculate the LTV of ETH in the Vault
    function calculateETHLTV() public view returns (uint256) {
        uint256 ethBalance = vault.getETHBalance();
        //@dev 90% of the ETH balance is used to calculate the amount
        //of cover tokens that can be minted, this could be adjusted
        //based on the python simulations
        uint256 ltv = (ethBalance * 100) / 90;
        return ltv;
    }

    //@dev Calculate the LTV of LRT in the Vault
    //@param lrt - the LRT token address
    function calculateLRTLTV(address lrt) public view returns (uint256) {
        uint256 lrtBalance = vault.getLRTBalance(lrt);
        //@dev 90% of the LRT balance is used to calculate the amount
        //of cover tokens that can be minted, this could be adjusted
        //based on the python simulations
        uint256 ltv = (lrtBalance * 100) / 90;
        return ltv;
    }

}
