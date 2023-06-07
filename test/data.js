const { ethers } = require("hardhat");

const DECIMALS = {
  TWO: 2,
  SIX: 6,
  EIGHTEEN: 18,
};

const MarketplaceAccess = ethers.utils.keccak256(
  ethers.utils.toUtf8Bytes("MARKETPLACE_ROLE")
);

const DAY = 24 * 60 * 60;
const YEAR = 365 * DAY;

const asset = {
  assetPrice: ethers.utils.parseUnits("10", DECIMALS.SIX),
  rewardApr: ethers.utils.parseUnits("10", DECIMALS.TWO), // with 2 decimals
  dueDate: Number(new Date("2023-11-12").getTime() / 1000), // in seconds
  lastSale: 0,
  lastClaim: 0,
};

const offer = {
  offerPrice: ethers.utils.parseUnits("5", DECIMALS.SIX),
  deadline: 3 * DAY, // in seconds
};

module.exports = {
  DAY,
  YEAR,
  asset,
  offer,
  DECIMALS,
  MarketplaceAccess,
};
