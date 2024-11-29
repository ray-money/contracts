// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IDeposit} from "../interfaces/IDeposit.sol";

contract LTVManager {
    IDeposit public deposit;

    constructor(address _deposit) {
        deposit = IDeposit(_deposit);
    }
    //@dev Calculate the LTV of ETH in the Vault
    function calculateETHLTV() public view returns (uint256) {
        uint256 ethBalance = deposit.getETHBalance();
        /** 
         * @dev 90% of the ETH balance is used to calculate the amount
         * of cover tokens that can be minted, this could be adjusted
         * based on the python simulations
         */
        uint256 ltv = (ethBalance * 100) / 90;
        return ltv;
    }

    //@dev Calculate the LTV of LRT in the Vault
    //@param lrt - the LRT token address
    function calculateLRTLTV(address lrt) public view returns (uint256) {
        uint256 lrtBalance = deposit.getLRTBalance(lrt);
        /** 
         * @dev 90% of the LRT balance is used to calculate the amount
         * of cover tokens that can be minted, this could be adjusted
         * based on the python simulations
         */
        uint256 ltv = (lrtBalance * 100) / 90;
        return ltv;
    }
}
