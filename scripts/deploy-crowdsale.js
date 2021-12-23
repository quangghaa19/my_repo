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

  // Get accounts
  const [owner, addr1, addr2, addr3, addr4] = await hre.ethers.getSigners();

  // Write all account to a file
  const account = [owner.address, addr1.address, addr2.address, addr3.address, addr4.address];
  fs.writeFileSync('./input_data/account.json', JSON.stringify(account));
  
  /**
   * Deploy Gameloft Token
   */
  const outputData = {};

  // Read data from gameloft token file
  const gameloftTokenFile = fs.readFileSync('./input_data/gameloftToken.json', 'utf8');

  const gameloftTokenData = JSON.parse(gameloftTokenFile);

  if (!gameloftTokenData || !gameloftTokenData.name || !gameloftTokenData.symbol || !gameloftTokenData.initialSupply || !gameloftTokenData.decimal) throw new Error("Invalid data");

  const GameloftToken = await hre.ethers.getContractFactory('GameloftToken');

  const gameloftToken = await GameloftToken.deploy(gameloftTokenData.name, gameloftTokenData.symbol, owner.address, gameloftTokenData.initialSupply, gameloftTokenData.decimal);
  await gameloftToken.deployed();

  const glTokenAddress = gameloftToken.address;
  outputData['glTokenAddress'] = glTokenAddress;
  console.log("Deployed Gameloft Token: ", glTokenAddress);
  
  /**
   * Deploy Crowdsale Token
   */
  
  const crowdSaleFile = fs.readFileSync('./input_data/crowdsale.json', 'utf8');
  const crowdSaleData = JSON.parse(crowdSaleFile);

  if (!crowdSaleData || !crowdSaleData.rate) throw new Error("Invalid Data");

  const CrowdSale = await ethers.getContractFactory('CrowdSale');
  const crowdSale = await CrowdSale.deploy(glTokenAddress, addr3.address, crowdSaleData.rate);
  await crowdSale.deployed();

  const crowdSaleAddress = crowdSale.address;
  outputData['crowdSaleAddress'] = crowdSaleAddress;
  console.log("Deployed CrowdSale: ", crowdSaleAddress);

  // Write deployed address to file
  fs.writeFileSync('./input_data/deployedAddresses.json', JSON.stringify(outputData));

  // Transfer token to crowsale contract
  const transferTx = await gameloftToken.transfer(crowdSaleAddress, gameloftToken.totalSupply());
  console.log("Token has been transfered to crowdsale contract");

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
