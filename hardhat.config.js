require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-foundry");

require('dotenv').config()
const accounts = [process.env.DEPLOYER_PK];

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "mainnet",
  networks: {
    hardhat: {
    },
    mainnet: {
      url: "https://rpc.ankr.com/eth",
      chainId: 1,
      accounts: accounts
    },
    arbitrum: {
      url: "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts: accounts
    },
    optimism: {
      url: "https://rpc.ankr.com/optimism",
      chainId: 10,
      accounts: accounts
    },
    polygon: {
      url: "https://rpc.ankr.com/polygon",
      chainId: 137,
      accounts: accounts
    }
  },
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      }
    ] 
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETH_API_KEY,
      arbitrumOne: process.env.ARBITRUM_API_KEY,
      optimisticEthereum: process.env.OPTIMISM_API_KEY,
      polygon: process.env.POLYGON_API_KEY
    },
    customChains: [],
  }
};