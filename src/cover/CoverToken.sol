// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ILTVManager} from "../interfaces/ILTVManager.sol";

contract CoverToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public baseAsset;
    address public ltvManager;
    bool private initialized;

    error AlreadyInitialized();
    error InvalidOwner();
    error InvalidLTVManager();
    error InvalidName();
    error InvalidSymbol();
    error AmountExceedsLTVLimit(uint256 amount, uint256 maxAmount);

    /** 
     * @dev Initialization function for the cloned contract
     * @param _owner - the owner of the contract, could be Controller.sol
     * @param _ltvManager - the LTVManager.sol address
     * @param _baseAsset - the base asset of the cover token, 0x if ETH or LRT address otherwise
     * @param _name - the name of the cover token
     * @param _symbol - the symbol of the cover token
     */
    function initialize(
        address _owner,
        address _ltvManager,
        address _baseAsset,
        string memory _name,
        string memory _symbol
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (_owner == address(0)) revert InvalidOwner();
        if (_ltvManager == address(0)) revert InvalidLTVManager();
        if (bytes(_name).length == 0) revert InvalidName();
        if (bytes(_symbol).length == 0) revert InvalidSymbol();
        
        __ERC20_init(_name, _symbol);
        _transferOwnership(_owner);
        ltvManager = _ltvManager;
        baseAsset = _baseAsset;
        initialized = true;
    }

    /**
     * @dev Mints tokens to an address. Can only be called by owner.
     * @param to The address that will receive the minted tokens
     * @param token The address of the LRT token, or address(0) for ETH
     * @param amount The amount of tokens to mint
     * @dev Uses LTVManager to check if amount is within allowed LTV limits
     */
    function mint(address to, address token, uint256 amount) external onlyOwner {
        uint256 maxAmount;
        if (token == address(0)) {
            // Get max allowed amount for ETH deposits
            maxAmount = ILTVManager(ltvManager).calculateETHLTV();
        } else {
            // Get max allowed amount for LRT token deposits
            maxAmount = ILTVManager(ltvManager).calculateLRTLTV(token);
        }
        if (amount > maxAmount) revert AmountExceedsLTVLimit(amount, maxAmount);
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
