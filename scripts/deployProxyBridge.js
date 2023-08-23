// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const { addressBook } = require("blockchain-addressbook");
const bridgeAbi = require("../artifacts/contracts/bridge/BeefyRevenueBridge.sol/BeefyRevenueBridge.json");
const deployerAbi = require("../artifacts/contracts/bridge/BeefyProxyDeployer.sol/BeefyProxyDeployer.json");
const {
  tokens: {
    ETH: { address: native },
    USDC: { address: stable },
  },
} = addressBook.zkevm;


const axelarParams = {
    chain: "Polygon",
    symbol: "axlUSDC"
}

const stargateParams = {
    dstChainId: 110,
    gasLimit: 0,
    srcPoolId: 1,
    dstPoolId: 1
}

const synapseParams = {
    chainId: 137,
    tokenIndexTo: 2,
    tokenIndexFrom: 0,
    token: "0xD8836aF2e565D3Befce7D906Af63ee45a57E8f80",
    dstIndexFrom: 0,
    dstIndexTo: 2
}

const beefyContractDeployer = "0xcc536552A6214d6667fBC3EC38965F7f556A6391";
const beefyContractDeployerAbi = ["function deploy(bytes32 _salt, bytes memory _bytecode) external returns (address)"];
const beefyBridgeImplementationSalt = "0x5c54e6d234a3c2222b59cf833671c9612a89518065a4ecf12ac6bbcb69bcf454";
const beefyProxyDeployerSalt = "0xe647ddf8d26f2415d3f90af679de723aff5732947b8e818f4026e9058419a0c8";
const beefyBridgeProxySalt = "0xf8c6154b5e6d912f4d46dc26b1f505505221c75612b89027a7ac012752fd4abf";

const path = ethers.utils.solidityPack(["address", "uint24", "address"], [native, 500, stable]);
const route = [native, stable];
const solidlyRoute = [[native, stable, false]];
const bridgeAddress = "0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe";
const router = "0xF6Ad3CcF71Abb3E12beCf6b3D2a74C963859ADCd";


const bridge = "zkEVM";
const swap = "ALGEBRA";

const deploy = true;
const deployProxyDeployer = false;
const deployImpl = true;

const addBridge = true;
const addSwap = true;

let destinationAddress = "0xc9C61194682a3A5f56BF9Cd5B59EE63028aB6041";
if (bridge == "STARGATE") destinationAddress = "0x5f98f630009E0E090965fb42DDe95F5A2d495445";
else if (bridge == "AXELAR") destinationAddress = "0xc0D173E3486F7C3d57E8a38a003500Fd27E7d055";

let bridgeContract = "0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B";

async function main() {
    const abiCoder = new ethers.utils.AbiCoder();
    const interface = new ethers.utils.Interface(bridgeAbi.abi);

    let contract;
    let tx;
   
    if (deploy) {
        const beefyDeployer = await ethers.getContractAt(beefyContractDeployerAbi, beefyContractDeployer);
        
        let proxyDeployerAddress = "0x0284c93E93771acBfe6886462daC827bfbf73fA4";
        if (deployProxyDeployer) {
            proxyDeployerAddress = await beefyDeployer.callStatic.deploy(beefyProxyDeployerSalt, deployerAbi.bytecode);
            tx = await beefyDeployer.deploy(beefyProxyDeployerSalt, deployerAbi.bytecode);
            await tx.wait();
            console.log(`Deployed New Beefy Proxy Deployer at: ${proxyDeployerAddress}`);
        }
      
        let impl = "0xB3D11a5c97ff5D3E8C6B3b9Df9358E27614778d9";
        if (deployImpl) {
            impl = await beefyDeployer.callStatic.deploy(beefyBridgeImplementationSalt, bridgeAbi.bytecode);
            tx = await beefyDeployer.deploy(beefyBridgeImplementationSalt, bridgeAbi.bytecode);
            await tx.wait();

            console.log(`Deploy Implementation at: ${impl}`);
        }

        proxyDeployer = await ethers.getContractAt(deployerAbi.abi, proxyDeployerAddress);
        
        const data = interface.encodeFunctionData("initialize()", []);
        proxyDeployer = await ethers.getContractAt(deployerAbi.abi, proxyDeployerAddress);
        bridgeContract = await proxyDeployer.callStatic.deployNewProxy(impl, data, beefyBridgeProxySalt);
        tx = await proxyDeployer.deployNewProxy(impl, data, beefyBridgeProxySalt, {gasLimit: 2000000});
        await tx.wait();
        
        console.log(`Deployed Proxy at: ${bridgeContract}`);
        contract = await ethers.getContractAt(bridgeAbi.abi, bridgeContract);

        tx = await contract.setDestinationAddress([destinationAddress, destinationAddress, destinationAddress]);
        await tx.wait();

        console.log(`Set Destination Address to: ${destinationAddress}`);
        
        tx = await contract.setStable(stable, native);
        await tx.wait();

        console.log(`Initialized Stable and Native`);
    } else contract = await ethers.getContractAt(bridgeAbi.abi, bridgeContract);
   
    if (addBridge) {
        if (bridge == "CIRCLE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint32"], [3])]);
            await tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }
    
        if (bridge == "STARGATE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint16", "uint256", "uint256", "uint256"], [stargateParams.dstChainId, stargateParams.gasLimit, stargateParams.srcPoolId, stargateParams.dstPoolId])]);
            await tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "SYNAPSE") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["uint256", "uint8", "uint8", "address", "uint8", "uint8"], [synapseParams.chainId, synapseParams.tokenIndexFrom, synapseParams.tokenIndexTo, synapseParams.token, synapseParams.dstIndexFrom, synapseParams.dstIndexTo])]);
            await tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "AXELAR") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, abiCoder.encode(["string", "string"], [axelarParams.chain, axelarParams.symbol])]);
            await tx.wait();
            console.log(`Set bridge to ${bridge}`);
        }

        if (bridge == "zkEVM") {
            let hash = await contract.findHash(bridge);
            tx = await contract.setActiveBridge(hash, [bridgeAddress, "0x"]);
            await tx.wait();
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
            await tx.wait();
            console.log(`Set swap to ${swap}`);
        }

        if (swap == "ALGEBRA") {
            let hash = await contract.findHash(swap);
            tx = await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["address[]"], [route])
                ]
            );
            await tx.wait();
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
            await tx.wait();
            console.log(`Set swap to ${swap}`);
        }
    
        if (swap == "UNISWAP_V3_DEADLINE") {
            let hash = await contract.findHash(swap);
            tx = await contract.setActiveSwap(
                hash,
                [
                    router,
                    abiCoder.encode(["bytes"], [path])
                ]
            );
            await tx.wait();
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
            await tx.wait();
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
