// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ERC4626} from "./tokens/ERC4626.sol";
import {ERC4626Rewards} from "./tokens/ERC4626Rewards.sol";
import {ERC20} from "./tokens/ERC20.sol";

contract Strategies {
    /*//////////////////////////////////////////////////////////////
                                 Data Structures
    //////////////////////////////////////////////////////////////*/
    
    struct Strategy {
        address vault;

        /// @notice The lower index is, the more junior the tranche is
        mapping(uint8 => address) trancheVaults;
    }

    /*//////////////////////////////////////////////////////////////
                                 States
    //////////////////////////////////////////////////////////////*/

    /// @notice Mapping from strategy ID to a Strategy struct
    mapping(uint256 => Strategy) public strategies;

    uint256 public strategyCount;

    address public immutable WETH;

    /*//////////////////////////////////////////////////////////////
                                Public interface
    //////////////////////////////////////////////////////////////*/

    constructor(address _WETH) {
        WETH = _WETH;
    }

    function createStrategy(
        uint8 _trancheCount,
        address[] calldata _rewardTokens
    ) external {
        uint256 _strategyID = strategyCount++;
        Strategy storage _strategy = strategies[_strategyID];

        // Create strategy vault
        address _strategyVault = address(new ERC4626Rewards(
            ERC20(WETH),
            string(abi.encodePacked("strategy-", _strategyID)),
            string(abi.encodePacked("strategy", _strategyID)),
            // To be continue
            _rewardTokens
        ));

        _strategy.vault = _strategyVault;
        
        // Create tranche vaults
        for (uint8 i = 0; i < _trancheCount; i++) {
            // We fix the gas consumption later. Initializing minimal clone seems too complex for contract safety.
            address trancheVault = address(new ERC4626(
                ERC4626(_strategyVault).asset(),
                string(abi.encodePacked("tranche-", i)),
                string(abi.encodePacked("tranche", i))
            ));
            strategies[_strategyID].trancheVaults[i] = trancheVault;
        }
    }
}