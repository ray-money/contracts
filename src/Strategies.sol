// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {StrategyVault} from "./tokens/StrategyVault.sol";
import {ERC20} from "./tokens/ERC20.sol";

contract Strategies {
    /*//////////////////////////////////////////////////////////////
                                 Data Structures
    //////////////////////////////////////////////////////////////*/
    
    struct Strategy {
        /// @notice Vault for holding the strategy's principal and rewards
        address vault;
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

    error ERR_SIZE();

    constructor(address _WETH) {
        WETH = _WETH;
    }

    function createStrategy(
        address[] calldata _rewardTokens
    ) external {
        uint256 _strategyID = strategyCount++;
        Strategy storage _strategy = strategies[_strategyID];

        // Create strategy vault
        address _strategyVault = address(new StrategyVault(
            ERC20(WETH),
            string(abi.encodePacked("strategy-", _strategyID)),
            string(abi.encodePacked("strategy", _strategyID)),
            // To be continue
            _rewardTokens
        ));

        _strategy.vault = _strategyVault;
    }
}