// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { addressBook } = require("blockchain-addressbook");
const bridgeAbi = require("../artifacts/contracts/bridge/BeefyRevenueBridge.sol/BeefyRevenueBridge.json");
const {
  tokens: {
    ETH: { address: native },
    USDC: { address: stable },
  },
} = addressBook.arbitrum;

const contractName = "BeefyRevenueBridge";

const stargateParams = {}
const synapseParams = {}
const axelarParams = {}

const path = ethers.utils.solidityPack(["address", "uint24", "address"], [native, 500, stable]);
const bridgeAddress = "0x19330d10D9Cc8751218eaf51E8885D058642E08A";
const router = "0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45";

const destinationAddress = "0x161D61e30284A33Ab1ed227beDcac6014877B3DE";
const bridge = "CIRCLE";
const swap = "UNISWAP_V3";

async function main() {
    const abiCoder = new ethers.utils.AbiCoder();
    const Contract = await hre.ethers.getContractFactory(contractName);
    const contract = await Contract.deploy();
    await contract.deployed();
    console.log(`Beefy Revenue Bridge is deployed at: ${contract.address}`);

    await contract.intialize(stable, native);
    console.log(`Beefy Revenue Bridge intialized`);

    await contract.setDestinationAddress([destinationAddress, destinationAddress, destinationAddress]);
    console.log(`Set Destination Address to: ${destinationAddress}`);

    if (bridge == "CIRCLE") {
        let hash = await contract.findHash(bridge);
        await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint32"], [1])]);
        console.log(`Set bridge to ${bridge}`);
    }

    if (swap == "UNISWAP_V3") {
        let hash = await contract.findHash(swap);
        await contract.setActiveSwap(
            hash,
            [
                router,
                abiCoder.encode(["bytes"], [path])
            ]
        );
        console.log(`Set swap to ${swap}`);
    }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
