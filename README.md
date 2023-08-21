## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
ETH: None {HUB} Arbitrum: Circle -> ETH 
Avalanche: Circle -> Arbitrum {HUB} 
Polygon: Stargate -> Arbitrum (Needs axlUSDC - USDC swap) 
Optimism: Stargate -> Abritrum 
BNB: Stargate -> Arbitrum 
Celo: Axelar -> Polygon 
Fantom: Axelar -> Polygon 
Kava: Axelar -> Polygon 
Cronos: Synapse -> Polygon 
Canto: Synapse -> Polygon 
Metis: Stargate -> Avax as USDT? 
Moonbeam: Axelar -> Polygon 
Moonriver: ? zkSync: 
zkBridge -> ETH 
Fuse: ? 
zkEVM: zkEVMBridge -> ETH 
Aurora: Synapse -> Polygon
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
