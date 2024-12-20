// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStrategy {
    function initialize(
        address _owner,
        address _markets,
        address _collateralAsset,
        string memory _name,
        string memory _symbol
    ) external;

    function mint(address to, uint256 amount) external;
    
    function burn(address from, uint256 amount) external;

    function collateralAsset() external view returns (address);
}
