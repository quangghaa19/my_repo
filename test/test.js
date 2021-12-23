
const { ethers } = require("hardhat");
const { expect } = require("chai");
const  fs  = require("fs");
const { isFunctionExpression } = require("typescript");

describe("CrowdSale Deployment", function () {
  let Token;
  let hardhatToken;
  let owner;
  let addr1;
  let addr2;
  let addr3;
  let addr4;
  let gameloftToken;
  let crowdSale;
  let gameloftTokenData;
  let crowdSaleData;
  let roundData;
  let accountData;

  beforeEach(async function () {
    [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    // Deploy token
    const gameloftTokenFile = fs.readFileSync('./input_data/gameloftToken.json', 'utf8');
    gameloftTokenData = JSON.parse(gameloftTokenFile);

    if (!gameloftTokenData || !gameloftTokenData.name || !gameloftTokenData.symbol || !gameloftTokenData.initialSupply || !gameloftTokenData.decimal) throw new Error("Invalid data");
    const GameloftToken = await hre.ethers.getContractFactory('GameloftToken');
    gameloftToken = await GameloftToken.deploy(gameloftTokenData.name, gameloftTokenData.symbol, owner.address, gameloftTokenData.initialSupply, gameloftTokenData.decimal);
    await gameloftToken.deployed();

    // Deploy crowdsale
    const crowdSaleFile = fs.readFileSync('./input_data/crowdsale.json', 'utf8');
    crowdSaleData = JSON.parse(crowdSaleFile);

    if (!crowdSaleData || !crowdSaleData.rate) throw new Error("Invalid Data");
    const CrowdSale = await ethers.getContractFactory('CrowdSale');
    crowdSale = await CrowdSale.deploy(gameloftToken.address, addr3.address, crowdSaleData.rate);
    await crowdSale.deployed();

    const roundDataFile = fs.readFileSync('./input_data/round.json', 'utf8');
    roundData = JSON.parse(roundDataFile);

  });
    
  // TC01: Deployment
  it("Should be the same as JSON data", async function () {

    expect(await gameloftToken.name()).to.equal(gameloftTokenData.name);
    expect(await gameloftToken.symbol()).to.equal(gameloftTokenData.symbol);

    expect(await crowdSale.rate()).to.equal(crowdSaleData.rate);
    expect(await crowdSale.token()).to.equal(gameloftToken.address);
  });

  // TC02: Create a round
  it("Should create pool", async function() {
    await crowdSale.createPool(roundData[0].poolId, roundData[0].name, roundData[0].totalPercent, roundData[0].timestamps, roundData[0].ratios);
    
  });

  // TC03: Add investor at addr1 & addr2
  it("Should add investor", async function() {
    await crowdSale.setInvestor("1", addr1.address, true);
    
  });

  // TC04: Buy token
  it("Should increase token in beneficial account and wei in collector account (1)", async function() {

    await crowdSale.connect(addr1).buyToken("1", addr1.address);

    expect(await gameloftToken.balanceOf(addr1.address)).to.equal(200000);
    expect(await crowdSale.balanceOf(addr3.address)).to.equal(100000);
  });

  // TC05: Buy specific amount of token
  it("Should increase token in beneficial account and wei in collector account (2)", async function() {

    await crowdSale.connect(addr2).buySpecificAmountOfToken("1", addr2.address, 200000);

    expect(await gameloftToken.balanceOf(addr1.address)).to.equal(200000);
    expect(await crowdSale.balanceOf(addr3.address)).to.equal(100000);
  });

});
