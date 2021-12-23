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

  const acountFile = fs.readFileSync('./input_data/account.json', 'utf8');
  const accountData = JSON.parse(acountFile);

  const tx = await crowdSale.setInvestor("1", accountData[1], true);
  const tx2 = await crowdSale.setInvestor("1", accountData[2], true);
  console.log("addr1 & addr2  has been set to be an investor for round 1");
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
