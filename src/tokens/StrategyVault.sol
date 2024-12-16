// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import {ERC4626} from "./ERC4626.sol";
import {ERC20} from "./ERC20.sol";

interface RewardLike {
    function withdraw(uint256 amount, address to) external;
}

/// @notice A modified ERC4626 that has admin whose privilage is limited to making
/// arbitrary calls to reward contract objects for harvesting reward.
/// @notice This vault is intended to be used to accept a custodian  (e.g. Symbiotic)
/// and let admin harvest.
/// @notice This vault lets depositors withdraw not only principal but also rewards, 
/// on every withdrawal.
contract StrategyVault is ERC4626 {
    address public admin;
    address[] public rewards;

    error ERR_AUTH();
    error ERR_CALL();
    error ERR_SIZE();
    
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address[] memory _rewards
    ) ERC4626(_asset, _name, _symbol) {
        admin = msg.sender;

        // This should be e.g. Symbiotic ERC4626 shares
        asset = _asset;

        rewards = _rewards;
    }
    
    function beforeWithdraw(uint256 assets, uint256) internal override {
        // Withdraw rewards on behalf of withdrawer
        for (uint256 i = 0; i < rewards.length; i++) {  
            (bool success, ) = rewards[i].call(
                abi.encodeWithSelector(
                    RewardLike.withdraw.selector,
                    assets,
                    msg.sender
            ));
            if (!success) revert ERR_CALL();
        }
    }

    function opearteOnRewards(bytes[] calldata data) public returns (bytes[] memory) {
        if (msg.sender != admin) revert ERR_AUTH();
        if (data.length != rewards.length) revert ERR_SIZE();

        bytes[] memory returnData = new bytes[](rewards.length);
        for (uint256 i = 0; i < rewards.length; i++) {
            (bool success, bytes memory datum) = rewards[i].call(data[i]);
            if (!success) revert ERR_CALL();
            returnData[i] = datum;
        }
        return returnData;
    }

    function changeAdmin(address to) public {
        if (msg.sender != admin) revert ERR_AUTH();
        admin = to;
    }
}