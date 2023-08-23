// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {

  const bifi = "0x0000000000000000000000000000000000000000";
  const xBIFI = "0x161A54739C7F4D601f3d6f7ed35A1387E9Eb857F";
  const lockbox = "0x0000000000000000000000000000000000000000";
  const endpoint = "0x3c2269811836af69497E5F486A85D7316753cf62";
  const gasLimit = 2000000;
  const Contract = await hre.ethers.getContractFactory("BeefyRevenueBridge");
  /*const contract = await Contract.deploy(
    bifi, 
    xBIFI, 
    lockbox, 
    gasLimit,
    endpoint
  );
*/

  const contract = await Contract.deploy();

  await contract.deployed();

  console.log(
    `Contract deployed to ${contract.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
