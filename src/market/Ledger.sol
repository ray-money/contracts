// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {
    ERR_LEN,
    ERR_TOTAL_LEVERAGE_NOT_ALLOWED,
    ERR_PER_MARKET_LEVERAGE_NOT_ALLOWED
} from "../Errors.sol";

interface LeverConstraintLike { 
    function isLeverageAllowed(uint256 _marketID, uint256 _capacity) external view returns (bool);
    function isLeverageAllowed(uint256[] calldata _marketIDs, uint256[] calldata _capacities) external view returns (bool);
}

contract Ledger {
    // TODO: implement
    address montroller;
    LeverConstraintLike leverConstraint;
    // (marketID, allocator) => capacity
    mapping(uint256 => mapping(address => uint256)) public allocations;

    constructor(address _montroller, address _leverConstraint) {
        montroller = _montroller;
        leverConstraint = LeverConstraintLike(_leverConstraint);
    }

    // Liquidity providers or Strategists can allocate capacity to a market
    // by providing a marketID and a capacity, specified as percentage of
    // msg.sender's balance in the Treasury.
    // There are 1) per-market capacity limit 2) total capacity limit,
    // together they constraint the levering of the said balance.
    // This is the mechanism to control the levering and ensures the market's solvency.
    function _alloc(uint256 _marketID, uint256 _capacity) internal {
        if (!leverConstraint.isLeverageAllowed(_marketID, _capacity)) revert ERR_PER_MARKET_LEVERAGE_NOT_ALLOWED();
        allocations[_marketID][msg.sender] = _capacity;
    }

    function alloc(uint256[] calldata _marketIDs, uint256[] calldata _capacities) external {
        if (_marketIDs.length != _capacities.length) revert ERR_LEN();
        if (!leverConstraint.isLeverageAllowed(_marketIDs, _capacities)) revert ERR_TOTAL_LEVERAGE_NOT_ALLOWED();
        for (uint256 i = 0; i < _marketIDs.length; i++) {
            _alloc(_marketIDs[i], _capacities[i]);
        }
    }
}
