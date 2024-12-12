// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Controller} from "./Controller.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IVault} from "lib/core/src/interfaces/vault/IVault.sol";


contract Burner {
    using EnumerableSet for EnumerableSet.AddressSet;

    Controller public immutable controller;
    
    // Set of supported assets for coverage
    EnumerableSet.AddressSet private supportedAssets;

    // Mapping from covered asset to cover token address
    mapping(address => address) public coveredAssetToCoverToken;

    // Base asset used for coverage
    address public immutable baseAsset;
    
    constructor(address _controller) {
        controller = Controller(_controller);
        
        // Get base asset from controller's vault
        address vault = controller.vault();
        baseAsset = IVault(vault).collateral();
        
        // Import supported assets from controller
        address[] memory assets = controller.getSupportedAssets();
        for(uint256 i = 0; i < assets.length; i++) {
            address asset = assets[i];
            supportedAssets.add(asset);
            coveredAssetToCoverToken[asset] = controller.coveredAssetToCoverToken(asset);
        }
    }

    /**
     * @notice Claims coverage for a covered asset by burning cover tokens after slashing
     * @param coveredAsset The address of the asset for which coverage is being claimed
     * @param amount The amount of coverage to claim
     * @dev Transfers covered asset and cover tokens from caller to this contract, sends base asset to caller
     */
    function claimCoverage(address coveredAsset, uint256 amount) external {
        // Get cover token address for the covered asset
        address coverToken = coveredAssetToCoverToken[coveredAsset];

        // Transfer cover tokens from caller and burn them
        IERC20(coverToken).transferFrom(msg.sender, address(this), amount);
        // IERC20(coverToken).burn(amount); // shouldn't work right now, we should arrange a role in CoverToken for that

        // Transfer covered asset from caller
        IERC20(coveredAsset).transferFrom(msg.sender, address(this), amount);

        // Transfer base asset to caller
        IERC20(baseAsset).transfer(msg.sender, amount);
    }
}
