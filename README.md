## Beefy Omnipool 

**Beefy's Revenue Bridging System**


## Documentation

https://docs.beefy.com

## Usage

### Build

```shell
ETH: None {HUB} Arbitrum: Circle -> ETH 
Avalanche: Circle -> Arbitrum {HUB} 
Polygon: Stargate -> Arbitrum (Needs axlUSDC - USDC swap) 
Optimism: Stargate -> Abritrum 
BNB: Stargate -> Arbitrum 
Celo: Axelar -> Polygon <Deprecated>
Fantom: Axelar -> Polygon 
Kava: Axelar -> Polygon 
Cronos: Synapse -> Polygon 
Canto: Synapse -> Polygon 
Metis: Stargate -> Avax as USDT? 
Moonbeam: Axelar -> Polygon 
Moonriver: ? 
zkSync: zkBridge -> ETH 
Fuse: ? 
zkEVM: zkEVMBridge -> ETH 
Aurora: Synapse -> Polygon <Deprecated>
Base: Stargate -> Arbitrum
```

### Test

```shell
$ yarn test:<network>
```

