// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import {ERC4626} from "./ERC4626.sol";
import {ERC20} from "./ERC20.sol";

// This takes 1 asset from depositors 
// but gives multiple rewards that are distinct from the asset.
// This has admin, and can make arbitrary calls to rewards.
contract ERC4626Rewards is ERC4626 {
    address[] public rewards;
    address public admin;
    
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
        address[] memory _rewards
    ) ERC4626(_asset, _name, _symbol) {
        asset = _asset;
        rewards = _rewards;
    }

    function beforeWithdraw(uint256 assets, uint256) internal override {
        // Withdraw on behalf of withdrawer
        for (uint256 i = 0; i < rewards.length; i++) {  
            (bool success, ) = rewards[i].call(
                abi.encodeWithSignature("withdraw(uint256,address)", assets, msg.sender)
            );
            require(success, "Call failed");
        }
    }

    function opearteOnRewards(bytes[] calldata data) public {
        require(msg.sender == admin, "Not admin");
        bytes[] memory returndata = new bytes[](rewards.length);
        for (uint256 i = 0; i < rewards.length; i++) {
            (bool success, bytes memory datum) = rewards[i].call(data[i]);
            require(success, "Call to reward failed");
            returndata[i] = datum;
        }
    }

    function changeAdmin(address to) public {
        require(msg.sender == admin, "Not admin");
        admin = to;
    }
}