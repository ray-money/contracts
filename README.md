# PoC of Ray CDS Insurance on Symbiiotic

```
    ██████╗  █████╗ ██╗   ██╗
    ██╔══██╗██╔══██╗╚██╗ ██╔╝
    ██████╔╝███████║ ╚████╔╝ 
    ██╔══██╗██╔══██║  ╚██╔╝  
    ██║  ██║██║  ██║   ██║   
    ╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   
```

> **Note**: This is a Proof of Concept (PoC) implementation. The system is not yet production-ready and should be used for testing and development purposes only.

This project implements a Credit Default Swap (CDS) like insurance system on Symbiotic that provides coverage against depegging events for ETH-pegged assets. The system acts as a Symbiotic Delegation Contract (SDC) with slashing mechanisms triggered when an ETH-pegged asset depegs from its target value.

## Overview

The system allows users to:
- Buy coverage for supported ETH-pegged assets
- Claim coverage when depegging events occur
- Stake as operators to provide insurance capacity
- Earn rewards for providing insurance coverage

## Key Components

### Controller
The main orchestrator contract that:
- Manages cover token creation and issuance
- Handles coverage buying and claiming
- Integrates with Symbiotic's vault system
- Manages operator staking and slashing

### Cover Tokens
- Each supported asset has its own cover token
- Cover tokens are ERC20 tokens representing insurance coverage
- Created using a minimal proxy pattern for gas efficiency
- Managed by the Controller contract

### Network Middleware
- Manages network operations and vault interactions
- Handles staking, slashing, and rewards distribution
- Provides interface to Symbiotic's core functionality

## Main Features

1. **Coverage Management**
   - Buy coverage for supported ETH-pegged assets
   - Claim coverage when depegging events occur
   - Automatic capacity calculation based on staked amounts

2. **Staking and Slashing**
   - Operators can stake to provide insurance capacity
   - Slashing mechanism triggered on depegging events
   - Rewards distribution for stakers and operators

3. **Asset Support**
   - Dynamic addition of supported assets
   - Each asset has its own cover token
   - Capacity management per asset

4. **Security Features**
   - Role-based access control
   - Slashing protection
   - Capacity limits based on staked amounts

## Development

This project is built using Foundry, a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

## Documentation

For more information about Foundry, visit: https://book.getfoundry.sh/
