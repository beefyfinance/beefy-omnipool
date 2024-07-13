// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const BigNumber = require("bignumber.js");

const bridgeAbi = require("../artifacts/contracts/bridge/BeefyRevenueBridge.sol/BeefyRevenueBridge.json");

async function main() {
    const bridge = "0x02Ae4716B9D5d48Db1445814b0eDE39f5c28264B"
    const cowllector = "0x03d9964f4D93a24B58c0Fc3a8Df3474b59Ba8557";
    const minAmount = .1;
    const minBridgeAmount = 4000;
    

    // minAmount to wei 
    const minAmountWei = BigNumber(minAmount).multipliedBy(BigNumber(10).pow(18));
    const minbrgamount = BigNumber(minBridgeAmount).multipliedBy(BigNumber(10).pow(6));

    const cowTuple = [
        true, 
        cowllector,
        BigInt(minAmountWei)
    ];

    const contract = await ethers.getContractAt(bridgeAbi.abi, bridge);

    /*
    let tx = await contract.transferOwnership("0x1EFaC1e630939ee5422557D986add59E4996a67C");
    await tx.wait();
    console.log("Ownership transferred to:", "0x1EFaC1e630939ee5422557D986add59E4996a67C");
/*
    
    const bridgeTo = await contract.destinationAddress();
    console.log("Bridge to:", bridgeTo);
    
*/
    let tx = await contract.setCowllector(cowTuple);
    await tx.wait();
    console.log("Cowllector set to:", cowllector);

    tx = await contract.setMinBridgeAmount(BigInt(minbrgamount))
    await tx.wait();
    console.log("MinBridgeAmount set to:", minBridgeAmount);
    
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });