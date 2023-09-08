// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

const axelarAbi = require("../artifacts/contracts/bridgeToken/adapters/axelar/AxelarBridge.sol/AxelarBridge.json");
const optimismAbi= require("../artifacts/contracts/bridgeToken/adapters/optimism/OptimismBridgeAdapter.sol/OptimismBridgeAdapter.json");
const ccipAbi= require("../artifacts/contracts/bridgeToken/adapters/ccip/CCIPBridgeAdapter.sol/CCIPBridgeAdapter.json");
const lazerZeroAbi= require("../artifacts/contracts/bridgeToken/adapters/layerzero/LayerZeroBridge.sol/LayerZeroBridge.json");
const XERC20Factory = require("../artifacts/contracts/bridgeToken/XERC20Factory.sol/XERC20Factory.json");

async function main() {

  const contractDeployer = "0xcc536552A6214d6667fBC3EC38965F7f556A6391";
  const beefyContractDeployerAbi = ["function deploy(bytes32 _salt, bytes memory _bytecode) external returns (address)"];
 
  // Salts for bridge deployments
  const layerZeroSalt = "0x33ca404c0efdcc5d177f46b95308c329849a2245e3aa8b603c435caca0c3b0c8";
  const optimismSalt = "0xb9d002dc0ef3fe6ad261547d71d0835cc059d8df85b02e127b1909564e82ef0c";
  const axelarSalt = "0xf1aa7215c3c549a12fe696ef8cfa7014c78ac7750b0c43cd631e32d149f2d80f";
  const ccipSalt = "0x973f05b98134c232372b0b15b96f8d1928e87c937d3506d2b1cb9972967893fc";

  const lazerZeroArgs = {
    gasLimit: 1500000,
    endpoint: "0x3c2269811836af69497E5F486A85D7316753cf62",
  }

  const optimismArgs = {
    bridge: "0x4200000000000000000000000000000000000007",
  }

  const ccipArgs = {
    router: "0x261c05167db67B2b619f9d312e0753f3721ad6E8"
  }

  const axelarArgs = {
    gasLimit: 1500000,  
    gateway: "0xe432150cce91c13a887f7D836923d5597adD8E31",
    gasService: "0x2d5d7d31F671F86C782533cc367F14109a082712"
  }

  const Factory = await hre.ethers.getContractFactory("XERC20Factory");
  const factory = await Factory.deploy();
  await factory.deployed();

  console.log("XERC20Factory deployed to:", factory.address);

  const Token = await hre.ethers.getContractFactory("BIFI");
  const token = await Token.deploy();
  await token.deployed();

  console.log("BIFI deployed to:", token.address);

  const xToken = await factory.callStatic.deployXERC20("xTest", "xTest", [], [], []);
  let tx = await factory.deployXERC20("xTest", "xTest", [], [], []);
  await tx.wait();

  console.log("xToken deployed to:", xToken);

  const lockbox = ethers.constants.AddressZero;
  const lockbox = await factory.callStatic.deployLockbox(xToken, token.address, false);
  tx = await factory.deployLockbox(xToken, token.address, false);
  await tx.wait();

  console.log("lockbox deployed to:", lockbox);

  const deployer = await hre.ethers.getContractAt(beefyContractDeployerAbi, contractDeployer);
  const axelarBridge = await deployer.callStatic.deploy(axelarSalt, axelarAbi.bytecode);
  tx = await deployer.deploy(axelarSalt, axelarAbi.bytecode);
  await tx.wait();

  console.log("Axelar Bridge deployed to:", axelarBridge);

  const optimismBridge = await deployer.callStatic.deploy(optimismSalt, optimismAbi.bytecode);
  tx = await deployer.deploy(optimismSalt, optimismAbi.bytecode);
  await tx.wait();

  console.log("Optimism Bridge deployed to:", optimismBridge);

  const ccipBridge = await deployer.callStatic.deploy(ccipSalt, ccipAbi.bytecode);
  tx = await deployer.deploy(ccipSalt, ccipAbi.bytecode);
  await tx.wait();

  console.log("CCIP Bridge deployed to:", ccipBridge);

  const lazerZeroBridge = await deployer.callStatic.deploy(layerZeroSalt, lazerZeroAbi.bytecode);
  tx = await deployer.deploy(layerZeroSalt, lazerZeroAbi.bytecode);
  await tx.wait();

  console.log("LazerZero Bridge deployed to:", lazerZeroBridge);

  const axelarBridgeContract = await hre.ethers.getContractAt(axelarAbi.abi, axelarBridge);
  tx = await axelarBridgeContract.initialize(token.address, xToken, lockbox, axelarArgs.gasLimit, axelarArgs.gateway, axelarArgs.gasService);
  await tx.wait();

  console.log("Axelar Bridge initialized");

  const optimismBridgeContract = await hre.ethers.getContractAt(optimismAbi.abi, optimismBridge);
  tx = await optimismBridgeContract.initialize(token.address, xToken, lockbox, optimismArgs.bridge);
  await tx.wait();

  console.log("Optimism Bridge initialized");

  const ccipBridgeContract = await hre.ethers.getContractAt(ccipAbi.abi, ccipBridge);
  tx = await ccipBridgeContract.initialize(token.address, xToken, lockbox, ccipArgs.router);
  await tx.wait();

  console.log("CCIP Bridge initialized");

  const lazerZeroBridgeContract = await hre.ethers.getContractAt(lazerZeroAbi.abi, lazerZeroBridge);
 tx = await lazerZeroBridgeContract.initialize(token.address, xToken, lockbox, lazerZeroArgs.gasLimit, lazerZeroArgs.endpoint);
  await tx.wait();

  console.log("LazerZero Bridge initialized");

  // Set Max For Test
  const amount = BigInt(80000e18)
  const xTokenContract = await hre.ethers.getContractAt("XERC20", xToken);
  tx = await xTokenContract.setLimits(axelarBridge, amount, amount)
  await tx.wait();

  console.log("Axelar Limits set");

  tx = await xTokenContract.setLimits(optimismBridge, amount, amount);
  await tx.wait();

  console.log("Optimism Limits set");

  tx = await xTokenContract.setLimits(ccipBridge, amount, amount);
  await tx.wait();

  console.log("CCIP Limits set");

  tx = await xTokenContract.setLimits(lazerZeroBridge, amount, amount);
  await tx.wait();

  console.log("LazerZero Limits set");

 let tx = await axelarBridgeContract.addChainIds([1], ["Ethereum"]);
  tx = await tx.wait();

  console.log("Axelar Chain Ids added");

  tx = await ccipBridgeContract.setChainIds([1], [BigInt(5009297550715157269)]);
  tx = await tx.wait();

  console.log("CCIP Chain Ids added");

  tx = await lazerZeroBridgeContract.addChainIds([1], [111]);
  tx = await tx.wait();

  console.log("LazerZero Chain Ids added");

  tx = await lazerZeroBridgeContract.setTrustedRemote(101, lazerZeroBridge);
  await tx.wait();

  console.log("LazerZero Trusted Remote set");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});