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
    AVAX: { address: native },
    USDC: { address: stable },
  },
} = addressBook.avax;

const contractName = "BeefyRevenueBridge";

const path = ethers.utils.solidityPack(["address", "uint24", "address"], [native, 500, stable]);
const route = [native, stable];
const bridgeAddress = "0x45A01E4e04F14f7A4a6702c74187c5F6222033cd";
const router = "0xE54Ca86531e17Ef3616d22Ca28b0D458b6C89106";

const destinationAddress = "0x0EF812f4c68DC84c22A4821EF30ba2ffAB9C2f3A";
const bridge = "SYNAPSE";
const swap = "UNISWAP_V2";

const deploy = false;
const addBridge = true;
const addSwap = false;

const bridgeContract = "0x8677d4F17E0f1338B7d8582802Bdd1000619152d"

async function main() {
    const abiCoder = new ethers.utils.AbiCoder();
    const Contract = await hre.ethers.getContractFactory(contractName);
   
    if (deploy) {
        const contract = await Contract.deploy();
        await contract.deployed();
        console.log(`Beefy Revenue Bridge is deployed at: ${contract.address}`);

        await contract.intialize(stable, native);
        console.log(`Beefy Revenue Bridge intialized`);

        await contract.setDestinationAddress([destinationAddress, destinationAddress, destinationAddress]);
        console.log(`Set Destination Address to: ${destinationAddress}`);
    } else contract = await ethers.getContractAt(bridgeAbi.abi, bridgeContract);
    
    if (addBridge) {
        if (bridge == "CIRCLE") {
            let hash = await contract.findHash(bridge);
            await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint32"], [3])]);
            console.log(`Set bridge to ${bridge}`);
        }
    
        if (bridge == "STARGATE") {
            let hash = await contract.findHash(bridge);
            await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint16", "uint256", "uint256", "uint256"], [110, 2000000, 1, 1])]);
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "SYNAPSE") {
            let hash = await contract.findHash(bridge);
            await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint256", "uint8", "uint8"], [110, 2000000, 1, 1])]);
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "AXELAR") {
            let hash = await contract.findHash(bridge);
            await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["string", "string"], [110, 2000000, 1, 1])]);
            console.log(`Set bridge to ${bridge}`);
        }
    }

    if (addSwap) {
        if (swap == "UNISWAP_V2") {
            let hash = await contract.findHash(swap);
            await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["address[]"], [route])
                ]
            );
            console.log(`Set swap to ${swap}`);
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
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
