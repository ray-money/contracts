// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {
    ERR_LEN,
    ERR_TOTAL_LEVERAGE_NOT_ALLOWED,
    ERR_PER_MARKET_LEVERAGE_NOT_ALLOWED,
    ERR_AUTH
} from "../Errors.sol";

interface LeverConstraintLike { 
    function isLeverageAllowed(uint256 _marketID, uint256 _capacityPct, uint256 _ethDeposit) external view returns (bool);
    function isLeverageAllowed(uint256[] calldata _marketIDs, uint256[] calldata _capacityPcts, uint256 _totalETHDeposit) external view returns (bool);
}

contract Ledger {
    /////////////////////////// Data Structures //////////////////////////////// 

    // Capacity's unit is ETH
    // Note: allocated is dynamically calculated on every read
    struct MarketCapacity {
        uint256 capacitySum;
        mapping(address => uint256) capacities;
    }

    address public admin;

    LeverConstraintLike public leverConstraint;

    uint256 public totalEthDeposit;

    // Mapping keccak256(msg.sender, account) to the account's ETH deposit balance
    // This is to use msg.sender to create a namespace so this object is decoupled
    // from the caller's address.
    // keccak256 is cheaper (30 GAS) than using a nested mapping (cold SLOAD is 2100 GAS).
    // TODO: should we use just make it callable only for Montroller? What can we be good if
    // we don't try to be the best?
    mapping(uint256 => uint256) public ethDeposits;

    // mapping market ID to MarketCapacity which contains total 
    // capacity allocated to the market and the capacity allocated by
    // each account in the market
    mapping(address => uint256 => mapping(address => uint256)) public marketCapacities;

    // mapping account to the market IDs the account is actively allocated to
    mapping(address => address => uint256[]) public reverseMarketCapacities;

    /////////////////////////// Constructor //////////////////////////////// 

    constructor(address _admin, address _leverConstraint) {
        admin = _admin;
        leverConstraint = LeverConstraintLike(_leverConstraint);
    }

    //////////////////////// Liquidity Provider methods ////////////////

    function depositETH(address _recipient) external payable {
        ethDeposits[msg.sender][_recipient] += msg.value;
        totalEthDeposit += msg.value;
    }

    // Allows any account to withdraw ETH from the Ledger.
    // Reverts on either a per-market or total leverage constraint violation.
    function withdrawETH(address _account, address _recipient, uint256 _amount) external {
        uint256 _newEthDeposit = ethDeposits[msg.sender][_account] - _amount;
        uint256[] memory _marketIDs = reverseMarketCapacities[msg.sender][_recipient];
        uint256[] memory _capacities = new uint256[](_marketIDs.length);
        for (uint256 i = 0; i < _marketIDs.length; i++) {     
            uint256 _marketID = _marketIDs[i];
            uint256 _capacity = marketCapacities[msg.sender][_marketID].capacities[_account];
            if (!leverConstraint.isLeverageAllowed(_marketID, _capacity, _newEthDeposit)) {
                revert ERR_PER_MARKET_LEVERAGE_NOT_ALLOWED();
            }
            _capacityPcts[i] = capacityPct;
        }
        if (!leverConstraint.isLeverageAllowed(_marketIDs, _capacities, _newEthDeposit)) {
            revert ERR_TOTAL_LEVERAGE_NOT_ALLOWED();
        }
        ethDeposits[_recipient] -= _amount;
    }

    // Liquidity providers or Strategists can allocate capacity to a market
    // by providing a marketID and a percentage of the deposit.
    // There are two leverage constrains: 1) per-market and 2) total.
    // Together, the constrains ensure each allocated market's solvency.
    // function alloc(uint256[] calldata _marketIDs, uint256[] calldata _capacityPcts) external {
    //     if (_marketIDs.length != _capacityPcts.length) {
    //         revert ERR_LEN();
    //     }
    //     if (!leverConstraint.isLeverageAllowed(_marketIDs, _capacityPcts, totalEthDeposits)) {
    //         revert ERR_TOTAL_LEVERAGE_NOT_ALLOWED();
    //     }
    //     for (uint256 i = 0; i < _marketIDs.length; i++) {
    //         _alloc(_marketIDs[i], _capacityPcts[i]);
    //     }
    // }

    //////////////////////////// Admin methods /////////////////////////////// 
    function sudo(uint8 _op, bytes calldata _args) external {
        if (msg.sender != admin) revert ERR_AUTH();
        if (_op == 0) {
            (address _admin) = abi.decode(_args, (address));
            admin = _admin;
        } else if (_op == 1) {
            (address _leverConstraint) = abi.decode(_args, (address));
            leverConstraint = LeverConstraintLike(_leverConstraint);
        } else {
            revert ERR_INVALID_OP();
        }
    }

    /////////////////////////// Internal methods /////////////////////////////// 
    // function _alloc(uint256 _marketID, uint256 _capacityPct) internal {
    //     // TODO: swap out msg.sender
    //     if (_capacityPct == 0) {
    //         marketCapacities[_marketID].capacitySum -= marketCapacities[_marketID].capacities[msg.sender];
    //         delete marketCapacities[_marketID].capacities[msg.sender];
    //         // TODO: swap remove to another method
    //         reverseMarketCapacities[msg.sender].remove(_marketID);
    //     } else {
    //         if (!leverConstraint.isLeverageAllowed(_marketID, _capacityPct, ethDeposits[msg.sender])) {
    //             revert ERR_PER_MARKET_LEVERAGE_NOT_ALLOWED();
    //         } 
    //         uint256 _capacity = ethDeposits[msg.sender] * _capacityPct / 100 / 1e18;
    //         marketCapacities[_marketID].capacitySum += _capacity;
    //         marketCapacities[_marketID].capacities[msg.sender] = _capacity;
    //         reverseMarketCapacities[msg.sender].push(_marketID);
    //     }
    // }
 }
