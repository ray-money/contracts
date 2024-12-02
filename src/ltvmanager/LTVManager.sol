// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {INetworkMiddleware} from "../interfaces/INetworkMiddleware.sol";

contract LTVManager {
    INetworkMiddleware public networkMiddleware;

    constructor(address _networkMiddleware) {
        networkMiddleware = INetworkMiddleware(_networkMiddleware);
    }

    //@dev Calculate the LTV of a token in the Vault
    //@param token - the token address
    function calculateLTV(address token) public view returns (uint256) {
        uint256 tokenBalance = networkMiddleware.getVaultActiveBalance(token, address(this));
        /** 
         * @dev 90% of the token balance is used to calculate the amount
         * of cover tokens that can be minted, this could be adjusted
         * based on the python simulations
         */
        uint256 ltv = (tokenBalance * 90) / 100;
        return ltv;
    }
}
