// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

//@dev Custom Errors
error AmountMismatch();
error InsufficientBalance(uint256 requested, uint256 available);
error InsufficientContractBalance(uint256 requested, uint256 available);
error TransferFailed();
error LRTNotWhitelisted(address lrt);
error ZeroAmount();
error InsufficientLRTBalance(uint256 requested, uint256 available);
error InsufficientAllowance(uint256 requested, uint256 allowed);
error DirectETHNotAllowed();

contract Vault {
    //@dev mapping of whitelisted LRTs
    mapping(address => bool) public whitelistedLRTs;
    //@dev Mapping to track user eth deposits
    mapping(address => uint256) public ethlps;
    //@dev Mapping to track user lrt deposits
    mapping(address => mapping(address => uint256)) public lrtlps;

    //@dev oracle address
    address public oracle;

    //@dev   constructor
    //@param _lrts - the list of LRTs to whitelist
    //@param _oracle - the oracle address
    constructor(address[] memory _lrts, address _oracle) {
        for(uint i = 0; i < _lrts.length; i++) {
            whitelistedLRTs[_lrts[i]] = true;
        }
        oracle = _oracle;
    }

    //@dev   deposit ETH to the vault
    //@param amount - the amount of ETH to deposit
    function depositETH(uint256 amount) public payable {
        if (msg.value != amount) revert AmountMismatch();
        ethlps[msg.sender] += amount;
    }

    //@dev   withdraw ETH from the vault
    //@param amount - the amount of ETH to withdraw
    function withdrawETH(uint256 amount) public {
        if (ethlps[msg.sender] < amount) revert InsufficientBalance(amount, ethlps[msg.sender]);
        
        ethlps[msg.sender] -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    //@dev   deposit LRT tokens to the vault
    //@param lrt - the LRT token address
    //@param amount - the amount of LRT tokens to deposit
    function depositLRT(address lrt, uint256 amount) public {
        if (!whitelistedLRTs[lrt]) revert LRTNotWhitelisted(lrt);
        if (amount == 0) revert ZeroAmount();
        
        IERC20 token = IERC20(lrt);

        if (token.balanceOf(msg.sender) < amount) revert InsufficientLRTBalance(amount,  token.balanceOf(msg.sender));
        if (token.allowance(msg.sender, address(this)) < amount) revert InsufficientAllowance(amount, token.allowance(msg.sender, address(this)));
        
        lrtlps[lrt][msg.sender] += amount;
        bool success = token.transferFrom(msg.sender, address(this), amount);
        if (!success) revert TransferFailed();
    }

    //@dev   withdraw LRT tokens from the vault
    //@param lrt - the LRT token address
    //@param amount - the amount of LRT tokens to withdraw
    function withdrawLRT(address lrt, uint256 amount) public {
        if (!whitelistedLRTs[lrt]) revert LRTNotWhitelisted(lrt);
        if (amount == 0) revert ZeroAmount();
        
        if (lrtlps[lrt][msg.sender] < amount) revert InsufficientLRTBalance(amount, lrtlps[lrt][msg.sender]);

        IERC20 token = IERC20(lrt);
        if (token.balanceOf(address(this)) < amount) revert InsufficientContractBalance(amount, token.balanceOf(address(this)));

        lrtlps[lrt][msg.sender] -= amount;

        bool success = token.transfer(msg.sender, amount);
        if (!success) revert TransferFailed();
    }

    //@dev Get the ETH balance of the contract
    function getETHBalance() public view returns (uint256) {
        return address(this).balance;
    }

    //@dev   Get the LRT token balance of the contract
    //@param lrt - the LRT token address
    function getLRTBalance(address lrt) public view returns (uint256) {
        return IERC20(lrt).balanceOf(address(this));
    }

    //@dev Check if LRT is whitelisted
    function isWhitelistedLst(address lrt) public view returns (bool) {
        return whitelistedLRTs[lrt];
    }

    //@dev Prevent direct ETH transfers
    receive() external payable {
        revert DirectETHNotAllowed();
    }

    //@dev Prevent direct ETH transfers with fallback
    fallback() external payable {
        revert DirectETHNotAllowed();
    }
}
