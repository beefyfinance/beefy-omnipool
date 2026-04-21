require("@nomiclabs/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require('@openzeppelin/hardhat-upgrades');

require('dotenv').config()
const accounts = [process.env.DEPLOYER_PK, process.env.KEEPER_PK];

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "mainnet",
  networks: {
    mainnet: {
      url: process.env.MAINNET_RPC || "https://rpc.ankr.com/eth",
      chainId: 1,
      accounts,
    },
    ethereum: {
      url: process.env.ETH_RPC || "https://rpc.ankr.com/eth",
      chainId: 1,
      accounts,
    },
    bsc: {
      url: "https://binance-smart-chain-public.nodies.app",
      chainId: 56,
      accounts,
    },
    heco: {
      url: process.env.HECO_RPC || "https://http-mainnet-node.huobichain.com",
      chainId: 128,
      accounts,
    },
    avax: {
      url: "https://avalanche-c-chain-rpc.publicnode.com",
      chainId: 43114,
      accounts,
    },
    polygon: {
      url: "https://polygon.rpc.subquery.network/public",
      chainId: 137,
      accounts,
      gasPrice: 300000000000
    },
    fantom: {
      url: process.env.FANTOM_RPC || "https://rpc.ankr.com/fantom",
      chainId: 250,
      accounts,
    },
    one: {
      url: process.env.ONE_RPC || "https://api.s0.t.hmny.io/",
      chainId: 1666600000,
      accounts,
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC || "https://arb1.arbitrum.io/rpc",
      chainId: 42161,
      accounts,
    },
    moonriver: {
      url: process.env.MOONRIVER_RPC || "https://rpc.moonriver.moonbeam.network",
      chainId: 1285,
      accounts,
    },
    celo: {
      url: process.env.CELO_RPC || "https://forno.celo.org",
      chainId: 42220,
      accounts,
    },
    cronos: {
      // url: "https://evm-cronos.crypto.org",
      url: process.env.CRONOS_RPC || "https://rpc.vvs.finance/",
      chainId: 25,
      accounts,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      timeout: 300000,
      accounts: "remote",
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545/",
      chainId: 97,
      accounts,
    },
    kovan: {
      url: "https://kovan.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161",
      chainId: 42,
      accounts,
    },
    aurora: {
      url: process.env.AURORA_RPC || "https://mainnet.aurora.dev/Fon6fPMs5rCdJc4mxX4kiSK1vsKdzc3D8k6UF8aruek",
      chainId: 1313161554,
      accounts,
    },
    fuse: {
      url: process.env.FUSE_RPC || "https://rpc.fuse.io",
      chainId: 122,
      accounts,
    },
    metis: {
      url: process.env.METIS_RPC || "https://andromeda.metis.io/?owner=1088",
      chainId: 1088,
      accounts,
    },
    moonbeam: {
      url: process.env.MOONBEAM_RPC || "https://rpc.api.moonbeam.network",
      chainId: 1284,
      accounts,
    },
    sys: {
      url: process.env.SYS_RPC || "https://rpc.syscoin.org/",
      chainId: 57,
      accounts,
    },
    emerald: {
      url: process.env.EMERALD_RPC || "https://emerald.oasis.dev",
      chainId: 42262,
      accounts,
    },
    optimism: {
      url: process.env.OPTIMISM_RPC || "https://rpc.ankr.com/optimism",
      chainId: 10,
      accounts,
    },
    kava: {
      url: process.env.KAVA_RPC || "https://evm.kava.io",
      chainId: 2222,
      accounts,
    },
    canto: {
      url: process.env.CANTO_RPC || "https://jsonrpc.canto.nodestake.top",
      chainId: 7700,
      accounts,
    },
    zkevm: {
      url: process.env.ZKEVM_RPC || "https://zkevm-rpc.com",
      chainId: 1101,
      accounts,
    },
    base : {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts
    },
    rollux : {
      url: "https://rpc.rollux.com",
      chainId: 570,
      accounts
    },
    linea : {
      url: "https://rpc.linea.build",
      chainId: 59144,
      accounts
    },
    mantle: {
      url: "https://rpc.mantle.xyz",
      chainId: 5000,
      accounts
    },
    mode: {
      url: "https://mode.drpc.org",
      chainId: 34443,
      accounts
    },
    sei: {
      url: "https://evm-rpc.sei-apis.com",
      chainId: 1329,
      accounts
    },
    fraxtal: {
      url: "https://rpc.frax.com",
      chainId: 252,
      accounts
    },
    real: {
      url: process.env.REAL_RPC || "https://real.drpc.org",
      chainId: 111188,
      accounts,
    },
    scroll: {
      url: "https://scroll-mainnet.public.blastapi.io",
      chainId: 534352,
      accounts
    },
    sonic: {
      url: "https://rpc.soniclabs.com",
      chainId: 146,
      accounts,
    },
    bera: {
      url: "https://rpc.berachain.com",
      chainId: 80094,
      accounts,
    },
    rootstock: {
      url: "https://public-node.rsk.co",
      chainId: 30,
      accounts,
      gasPrice: 72000000
    },
    saga: {
      url: "https://sagaevm.jsonrpc.sagarpc.io",
      chainId: 5464,
      accounts,
      gasPrice: 0,               
      timeout: 90_000,
    },
    hyperevm: {
      url: "https://rpc.hyperliquid.xyz/evm",
      chainId: 999,
      accounts,
    },
    lisk: {
      url: "https://lisk.drpc.org",
      chainId: 1135,
      accounts,
    },
    plasma: {
      url: "https://rpc.plasma.to",
      chainId: 9745,
      accounts,
    },
    monad: {
      url: "https://rpc-mainnet.monadinfra.com",
      chainId: 143,
      accounts,
    },
    megaeth: {
      url: "https://mainnet.megaeth.com/rpc",
      chainId: 4326,
      accounts,
    },
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
      },
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        },
      }
    ] 
  },
  sourcify: {
    enabled: false
  },
  etherscan: {
    enabled: true,
    apiKey: process.env.ETHERSCAN_API_KEY,
    customChains: [
      {
        network: "megaeth",
        chainId: 4326,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=4326&apikey=",
          browserURL: "https://mega.etherscan.com/",
        },
      },
      {
        network: "monad",
        chainId: 143,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=143&apikey=",
          browserURL: "https://monadscan.com/",
        },
      },
      {
        network: "plasma",
        chainId: 9745,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/plasma/evm/9745/etherscan?apiKey=",
          browserURL: "https://plasmascan.to/",
        },
      },
      {
        network: "lisk",
        chainId: 1135,
        urls: {
          apiURL: "https://blockscout.lisk.com/api",
          browserURL: "https://blockscout.lisk.com/"
        }
      },
      {
        network: "hyperevm",
        chainId: 999,
        urls: {
          apiURL: "https://www.hyperscan.com/api",
          browserURL: "https://www.hyperscan.com/",
        },
      },
      {
        network: "saga",
        chainId: 5464,
        urls: {
          apiURL: "https://api-sagaevm.sagaexplorer.io/api",
          browserURL: "https://sagaevm.sagaexplorer.io:443"
        }
      },
      {
        network: "rootstock",
        chainId: 30,
        urls: {
          apiURL: "https://rootstock.blockscout.com/api",
          browserURL: "https://rootstock.blockscout.com/"
        }
      },
      {
        network: "bera",
        chainId: 80094,
        urls: {
          apiURL: "https://api.berascan.com/api",
          browserURL: "https://berascan.com/",
        },
      },
      {
        network: "sonic",
        chainId: 146,
        urls: {
          apiURL: "https://api.sonicscan.org/api",
          browserURL: "https://sonicscan.org/",
        },
      },
      {
        network: "scroll",
        chainId: 534352,
        urls: {
          apiURL: "https://api.scrollscan.com/api",
          browserURL: "https://scrollscan.com/",
        },
      },
      {
        network: "aurora",
        chainId: 	1313161554,
        urls: {
          apiURL: "https://explorer.mainnet.aurora.dev/api",
          browserURL: "https://explorer.mainnet.aurora.dev/"
        }
      },
      {
        network: "kava",
        chainId: 2222,
        urls: {
          apiURL: "https://explorer.kava.io/api",
          browserURL: "https://explorer.kava.io/"
        }
      },
      {
        network: "fuse",
        chainId: 122,
        urls: {
          apiURL: "https://explorer.fuse.io/api",
          browserURL: "https://explorer.fuse.io"
        }
      },
      {
        network: "canto",
        chainId: 7700,
        urls: {
          apiURL: "https://tuber.build/api",
          browserURL: "https://tuber.build/"
        },
      },
      {
        network: "base_goerli",
        chainId: 84531,
        urls: {
          apiURL: 'https://api-goerli.basescan.org/api',
          browserURL: 'https://goerli.basescan.org'
        }
      },
      {
        network: "celo",
        chainId: 42220,
        urls: {
          apiURL: 'https://api.celoscan.io/api',
          browserURL: 'https://api.celoscan.io'
        }
      },
      {
        network: "cronos",
        chainId: 25,
        urls: {
          apiURL: 'https://api.cronoscan.com/api',
          browserURL: 'https://cronoscan.com'
        }
      },
      {
        network: "metis",
        chainId: 1088,
        urls: {
          apiURL: 'https://andromeda-explorer.metis.io/api',
          browserURL: 'https://andromeda-explorer.metis.io'
        }
      },
      {
        network: "zkevm",
        chainId: 1101,
        urls: {
          apiURL: "https://api-zkevm.polygonscan.com/api",
          browserURL: "https://zkevm.polygonscan.com/",
        },
      },
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
      {
        network: "mantle",
        chainId: 5000,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/5000/etherscan",
          browserURL: "https://mantlescan.info",
        },
      },
      {
        network: "linea",
        chainId: 59144,
        urls: {
          apiURL: "https://api.etherscan.io/v2/api?chainid=59144&apikey=",
          browserURL: "https://lineascan.build/",
        },
      },
      {
        network: "mode",
        chainId: 34443,
        urls: {
          apiURL: "https://explorer.mode.network/api",
          browserURL: "https://explorer.mode.network/",
        },
      },
      {
        network: "fraxtal",
        chainId: 252,
        urls: {
          apiURL: "https://api.fraxscan.com/api",
          browserURL: "https://fraxscan.com",
        },
      },
      {
        network: "sei",
        chainId: 1329,
        urls: {
          apiURL: "https://seitrace.com/pacific-1/api",
          browserURL: "https://seitrace.com"
        }
      },
      {
        network: "real",
        chainId: 111188,
        urls: {
          apiURL: "https://explorer.re.al/api",
          browserURL: "https://explorer.re.al",
        },
      }
    ]
  }
};