const { ethers } = require("hardhat");

const DECIMALS = {
  TWO: 2,
  SIX: 6,
  EIGHTEEN: 18,
};

const DAY = 24 * 60 * 60;
const YEAR = 365 * DAY;

const invoice = {
  assetPrice: ethers.utils.parseUnits("10", DECIMALS.SIX),
  rewardApr: ethers.utils.parseUnits("10", DECIMALS.TWO), // with 2 decimals
  dueDate: Number(new Date("2023-11-12").getTime() / 1000), // in seconds
  lastSale: 0,
  lastClaim: 0,
};

module.exports = {
  DAY,
  YEAR,
  invoice,
  DECIMALS,
};
