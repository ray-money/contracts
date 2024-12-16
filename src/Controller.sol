// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @notice Orchestrates and implement the workflows of the protocol.
/// @dev This shouldn't have states. States should be stored in the dependencies.
contract Controller {
    function provideLiquidity(
        address _custodian,
        address _strategy, 
        uint256 _underlyingAmount
    ) external {
        // TODO: Implement
        // 1. LP approves spending
        // 2. Controller deposits asset into strategy vault, depositing the underlying asset of the strategy into the custodian.
        // 3. The strategy holds the receipt of the custodian.
        // 4. LP receives shares of the strategy vault. Shares won't be redeemable for the underlying asset for some agreed upon amount of time.
        // 5. Admin of the strategy vault can claim rewards on behalf of the LPs. 
    }

    function withdrawLiquidity(address strategy, uint256 amount) external {
        // TODO: Implement
    }

    function setCapacity(address market, uint256 amount) external {
        // TODO: Implement
    }
}