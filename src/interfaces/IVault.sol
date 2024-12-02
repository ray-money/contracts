// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IVault {
    function whitelistedLRTs(address) external view returns (bool);
    function ethlps(address) external view returns (uint256);
    function lrtlps(address, address) external view returns (uint256);
    function oracle() external view returns (address);
    
    function depositETH(uint256 amount) external payable;
    function withdrawETH(uint256 amount) external;
    function depositLRT(address lrt, uint256 amount) external;
    function withdrawLRT(address lrt, uint256 amount) external;
    
    function getETHBalance() external view returns (uint256);
    function getLRTBalance(address lrt) external view returns (uint256);
    function isWhitelistedLst(address lrt) external view returns (bool);
}
