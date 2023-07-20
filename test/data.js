const { ethers } = require("hardhat");

const DECIMALS = {
  TWO: 2,
  SIX: 6,
  EIGHTEEN: 18,
};

const MarketplaceAccess = ethers.keccak256(
  ethers.toUtf8Bytes("MARKETPLACE_ROLE")
);

const DAY = 24n * 60n * 60n;
const YEAR = 360n * DAY;

const asset = {
  assetPrice: ethers.parseUnits("10", DECIMALS.SIX),
  rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
  dueDate: Number(new Date("2023-11-12").getTime() / 1000), // in seconds
  lastSale: 0,
  lastClaim: 0,
};

const property = {
  value: 3000,
  size: 200,
  bathrooms: 2,
  rooms: 3,
  constructionDate: Number(new Date("2020-11-12").getTime() / 1000),
  country: "Italy",
  city: "Rome",
  location: "https://goo.gl/maps/bEBPrewmyJB8v6CG8",
};

const offer = {
  offerPrice: ethers.parseUnits("5", DECIMALS.SIX),
  deadline: 3n * DAY, // in seconds
};

module.exports = {
  DAY,
  YEAR,
  asset,
  property,
  offer,
  DECIMALS,
  MarketplaceAccess,
};
