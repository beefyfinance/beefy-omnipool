// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

// [stargate composer, wnative address]
const config = {
  1: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"], // Mainnet
  56: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c"], // BSC
  43114: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7"], // AVAX
  137: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270"], // Polygon
  42161: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"], // Arbitrum
  10 : ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x4200000000000000000000000000000000000006"], // Optimism
  250: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83"], // Fantom
  1088: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x75cb093E4D61d2A2e65D8e0BBb01DE8d89b53481"], // Metis
  8453: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0x4200000000000000000000000000000000000006"], // Base
  59144: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f"], // Linea
  2222: ["0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9", "0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b"], // Kava
  5000: ["0x296F55F8Fb28E498B858d0BcDA06D955B2Cb3f97", "0x78c1b0C915c4FAA5FffA6CAbf0219DA63d7f4cb8"], // Mantle
}

async function main() {
  const chainConfig = config[hre.network.config.chainId];

  if (!chainConfig) {
    throw new Error(`Missing stargate composer and wnative address for chainId ${hre.network.chainId}`);
  }

  const zapReceiverFactory = await hre.ethers.getContractFactory("BeefyStargateZapReceiver");
  const zapReceiver = await zapReceiverFactory.deploy();
  await zapReceiver.deployed();

  console.log("Beefy Stargate Zap Receiver Deployed to:", zapReceiver.address);

  let tx = await zapReceiver.initialize(...chainConfig);
  await tx.wait();

  console.log("Zap Receiver Initialized");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});