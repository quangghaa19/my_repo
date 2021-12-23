// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const fs = require("fs");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // Read deployed address file
  const addressFile = fs.readFileSync('./input_data/deployedAddresses.json', 'utf8');
  const data = JSON.parse(addressFile);

  if (!data || !data.crowdSaleAddress) throw new Error("Invalid data");

  const crowdSaleAddress = data.crowdSaleAddress;
  const crowdSale = await ethers.getContractAt('CrowdSale', crowdSaleAddress);

  // Read round data file
  const roundDataFile = fs.readFileSync('./input_data/round.json', 'utf8');
  const roundData = JSON.parse(roundDataFile);

  for (let i = 0; i < roundData.length; i++) {
    const tx = await crowdSale.createPool(roundData[i].poolId, roundData[i].name, roundData[i].totalPercent, roundData[i].timestamps, roundData[i].ratios);
    console.log("Set round: ", roundData[i].poolId);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
