// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "lib/openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract CoverToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public collateralAsset;
    bool private initialized;

    error AlreadyInitialized();
    error InvalidOwner();
    error InvalidName();
    error InvalidSymbol();
    error AmountExceedsCapacity(uint256 amount, uint256 maxAmount);

    /** 
     * @dev Initialization function for the cloned contract
     * @param _owner - the owner of the contract, could be Controller.sol
     * @param _collateralAsset - the collateral asset of the cover token
     * @param _name - the name of the cover token
     * @param _symbol - the symbol of the cover token
     */
    function initialize(
        address _owner,
        address _collateralAsset,
        string memory _name,
        string memory _symbol
    ) external {
        if (initialized) revert AlreadyInitialized();
        if (_owner == address(0)) revert InvalidOwner();
        if (bytes(_name).length == 0) revert InvalidName();
        if (bytes(_symbol).length == 0) revert InvalidSymbol();
        
        __ERC20_init(_name, _symbol);
        _transferOwnership(_owner);
        collateralAsset = _collateralAsset;
        initialized = true;
    }

    /**
     * @dev Mints tokens to an address. Can only be called by owner.
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
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