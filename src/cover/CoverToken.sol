// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {ILTVManager} from "../interfaces/ILTVManager.sol";

contract CoverToken is ERC20, Ownable {
    address public ltvManager;

    /** 
     * @dev We should figure out naming for LRT/ETH specific cover tokens
     * @param _owner - the owner of the contract, could be Controller.sol
     * @param _ltvManager - the LTVManager.sol address
     */
    constructor(address _owner, address _ltvManager) ERC20("Cover Token", "COVER") Ownable(_owner) {
        ltvManager = _ltvManager;
    }

    /**
     * @dev Mints tokens to an address. Can only be called by owner.
     * @param to The address that will receive the minted tokens
     * @param token The address of the LRT token, or address(0) for ETH
     * @dev Uses LTVManager to calculate mint amount based on token type
     */
    function mint(address to, address token) external onlyOwner {
        uint256 amount;
        if (token == address(0)) {
            // Calculate LTV for ETH deposits
            amount = ILTVManager(ltvManager).calculateETHLTV();
        } else {
            // Calculate LTV for LRT token deposits
            amount = ILTVManager(ltvManager).calculateLRTLTV(token);
        }
        _mint(to, amount);
    }

    /**
     * @dev Burns tokens from an address. Can only be called by owner.
     * @param from The address to burn tokens from
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
