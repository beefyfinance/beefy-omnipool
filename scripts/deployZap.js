// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const stargate = "0xeCc19E177d24551aA7ed6Bc6FE566eCa726CC8a9";
  const native = "0x4200000000000000000000000000000000000006";
  const chainId = "111";
  const dstChainId = "110";
  const usdce = "0x7F5c764cBc14f9669B88837ca1490cCa17c31607";

  const ethVault = "0x6443ac40DcD204739b8127F1aaec53071bBca7DF";
  const usdceVault = "0x0da5EF5F02B8156a9a191d080369E420243C4501";

  const realChainId = 42161;

  const Bridge = await hre.ethers.getContractFactory("BeefyStargateZap");
  const bridge = await Bridge.deploy();
  await bridge.deployed();

  console.log("Beefy Stargate Zap Deployed to:", bridge.address);

  let tx = await bridge.initialize(stargate, native, chainId);
  await tx.wait();

  console.log("Bridge Initialized");

  tx = await bridge.addZappableVaults(dstChainId, [native, usdce], [ethVault, usdceVault]);
  await tx.wait();
  console.log("Vaults Added");

  tx = await bridge.addInputTokens(dstChainId, [native, usdce], [13, 1], [13, 1]);
  await tx.wait();

  console.log("Input Tokens Added");

  
  tx = await bridge.addChains([chainId], [realChainId], ["0xF083a9bbDb1F2Ac5a2829aC6bf6148847D8B4042"], [1500000]);
  await tx.wait();

  console.log("Chains Added");
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});