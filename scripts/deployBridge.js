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
    CANTO: { address: native },
    USDC: { address: stable },
    NOTE: { address: NOTE}
  },
} = addressBook.canto;

const contractName = "BeefyRevenueBridge";

const axelarParams = {
    chain: "Polygon",
    symbol: "axlUSDC"
}

const path = ethers.utils.solidityPack(["address", "uint24", "address"], [native, 500, stable]);
const route = [native, stable];
const solidlyRoute = [[native, NOTE, false],[NOTE, stable, true]];
const bridgeAddress = "0x8671A0465844a15eb7230C5dd8d6032c26c655B7";
const router = "0xa252eEE9BDe830Ca4793F054B506587027825a8e";

const destinationAddress = "0x161D61e30284A33Ab1ed227beDcac6014877B3DE";
const bridge = "SYNAPSE";
const swap = "SOLIDLY";

const deploy = false;
const addBridge = true;
const addSwap = false;

const bridgeContract = "0xe103ab2f922aa1a56EC058AbfDA2CeEa1e95bCd7"

async function main() {
    const abiCoder = new ethers.utils.AbiCoder();
    const Contract = await hre.ethers.getContractFactory(contractName);
   
    if (deploy) {
        const contract = await Contract.deploy();
        await contract.deployed();
        console.log(`Beefy Revenue Bridge is deployed at: ${contract.address}`);

        let tx = await contract.intialize(stable, native);
        tx.wait();
        console.log(`Beefy Revenue Bridge intialized`);

        tx = await contract.setDestinationAddress([destinationAddress, destinationAddress, destinationAddress]);
        tx.wait();
        console.log(`Set Destination Address to: ${destinationAddress}`);
    } else contract = await ethers.getContractAt(bridgeAbi.abi, bridgeContract);
   
    if (addBridge) {
        if (bridge == "CIRCLE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint32"], [3])]);
            tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }
    
        if (bridge == "STARGATE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint16", "uint256", "uint256", "uint256"], [110, 2000000, 1, 1])]);
            tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "SYNAPSE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint256", "uint8", "uint8", "address", "uint8", "uint8"], [137, 2, 0, "0xD8836aF2e565D3Befce7D906Af63ee45a57E8f80", 0, 2])]);
            tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "AXELAR") {
            let hash = await contract.findHash(bridge);
            console.log(axelarParams.chain, axelarParams.symbol)
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["string", "string"], [axelarParams.chain, axelarParams.symbol])]);
            tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }
    }

    if (addSwap) {
        if (swap == "UNISWAP_V2") {
            let hash = await contract.findHash(swap);
            tx = await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["address[]"], [route])
                ]
            );
            tx.wait();
            console.log(`Set swap to ${swap}`);
        }
    
        if (swap == "UNISWAP_V3") {
            let hash = await contract.findHash(swap);
            tx = await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["bytes"], [path])
                ]
            );
            tx.wait();
            console.log(`Set swap to ${swap}`);
        }

        if (swap == "SOLIDLY") {
            let hash = await contract.findHash(swap);
            tx = await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["tuple[](address,address,bool)"], [solidlyRoute])
                ]
            );
            tx.wait();
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
