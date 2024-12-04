// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ICoverToken {
    function initialize(
        address _owner,
        address _ltvManager,
        address _baseAsset,
        string memory _name,
        string memory _symbol
    ) external;

    function mint(address to, address token, uint256 amount) external;
    
    function burn(address from, uint256 amount) external;

    function baseAsset() external view returns (address);
    
    function ltvManager() external view returns (address);
}
