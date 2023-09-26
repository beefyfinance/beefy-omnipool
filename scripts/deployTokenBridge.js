// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const BigNumber = require("bignumber.js");

const axelarAbi = require("../artifacts/contracts/bridgeToken/adapters/axelar/AxelarBridge.sol/AxelarBridge.json");
const optimismAbi= require("../artifacts/contracts/bridgeToken/adapters/optimism/OptimismBridgeAdapter.sol/OptimismBridgeAdapter.json");
const ccipAbi= require("../artifacts/contracts/bridgeToken/adapters/ccip/CCIPBridgeAdapter.sol/CCIPBridgeAdapter.json");
const lazerZeroAbi= require("../artifacts/contracts/bridgeToken/adapters/layerzero/LayerZeroBridge.sol/LayerZeroBridge.json");
const XERC20Factory = require("../artifacts/contracts/bridgeToken/XERC20Factory.sol/XERC20Factory.json");

async function main() {

  const contractDeployer = "0xcc536552A6214d6667fBC3EC38965F7f556A6391";
  const beefyContractDeployerAbi = ["function deploy(bytes32 _salt, bytes memory _bytecode) external returns (address)"];
 
  // Salts for bridge deployments
  const layerZeroSalt = "0x6f8f870c622c865d5a8f260cfe1f931ebcba17b57b1380e457db5445268cfe32";
  const optimismSalt = "0xc15f1de73673ddc4bcd3eda396774c1c8aeada81004436efd312f93a7b6875ab";
  const axelarSalt = "0x791782a92c3628b9fdcf7182b854f2423b26da720a82f495c693438420d0f3e3";
  const ccipSalt = "0x794be46e0fea1a6073d4536f084685c651ddcde4082d7243a21f6afa0bf21a79";

  const lazerZeroArgs = {
    gasLimit: 300000,
    endpoint: "0x3c2269811836af69497E5F486A85D7316753cf62",
  }

  const optimismArgs = {
    //bridge: "0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1"
    bridge: "0x4200000000000000000000000000000000000007",
  }

  const ccipArgs = {
    router: "0x261c05167db67B2b619f9d312e0753f3721ad6E8"
  }

  const axelarArgs = {
    //gasLimit: 300000,  
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

  let tx = await token.initialize("0x161D61e30284A33Ab1ed227beDcac6014877B3DE");
  await tx.wait();

  console.log("BIFI deployed to:", token.address);

  const xToken = await factory.callStatic.deployXERC20("Test", "Test", [], [], []);
  tx = await factory.deployXERC20("Test", "Test", [], [], []);
  await tx.wait();

  console.log("xToken deployed to:", xToken);


 //const lockbox = ethers.constants.AddressZero;
  const lockbox = await factory.callStatic.deployLockbox(xToken, token.address, false);
  tx = await factory.deployLockbox(xToken, token.address, false);
  await tx.wait();

  console.log("lockbox deployed to:", lockbox);
/*
  const xToken = "0x665E21ce21B1e7c7401647c1fb740981b270b71d";
  const token = {
    address: xToken
  }

  const lockbox = ethers.constants.AddressZero;
*/
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
  tx = await axelarBridgeContract.initialize(token.address, xToken, lockbox, axelarArgs.gateway, axelarArgs.gasService);
  await tx.wait();

  console.log("Axelar Bridge initialized");

  const optimismBridgeContract = await hre.ethers.getContractAt(optimismAbi.abi, optimismBridge);
  tx = await optimismBridgeContract.initialize(token.address, xToken, lockbox, optimismArgs.bridge);
  await tx.wait();

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

  tx = await axelarBridgeContract.addChainIds([1, 42161], ["Ethereum", "arbitrum"]);
  tx = await tx.wait();

  console.log("Axelar Chain Ids added");


  tx = await ccipBridgeContract.setChainIds([1], [BigInt("5009297550715157269")]);
  tx = await tx.wait();

  console.log("CCIP Chain Ids added");

  tx = await lazerZeroBridgeContract.addChainIds([1, 10], [101, 111]);  
  tx = await tx.wait();

  console.log("LazerZero Chain Ids added");

  tx = await lazerZeroBridgeContract.setTrustedRemoteAddress(101, lazerZeroBridge);
  await tx.wait();

  tx = await lazerZeroBridgeContract.setTrustedRemoteAddress(111, lazerZeroBridge);
  await tx.wait();

  console.log("LazerZero Trusted Remote set");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});