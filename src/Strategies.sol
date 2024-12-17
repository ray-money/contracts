// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {StrategyVault} from "./tokens/StrategyVault.sol";
import {ERC20} from "./tokens/ERC20.sol";

struct Strategy {
    /// @notice Vault for holding the custodian tokens and rewards
    address vault;
    address admin;
    address custodian;
    address underlying;
}

contract Strategies {
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
    error ERR_AUTH();

    constructor(address _WETH) {
        WETH = _WETH;
    }

    function createStrategy(
        address _custodian,
        address _underlying,
        address _admin,
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

        // Write to storage
        _strategy.vault = _strategyVault;
        _strategy.custodian = _custodian;
        _strategy.underlying = _underlying;
        _strategy.admin = _admin;
    }

    function changeAdmin(uint256 _strategyID, address _admin) external {
        if (msg.sender != strategies[_strategyID].admin) revert ERR_AUTH();
        strategies[_strategyID].admin = _admin;
    }   
}