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
const YEAR = 360 * DAY;

const asset = {
  assetPrice: ethers.utils.parseUnits("10", DECIMALS.SIX),
  rewardApr: ethers.utils.parseUnits("10", DECIMALS.TWO), // with 2 decimals
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
    location: "https://goo.gl/maps/bEBPrewmyJB8v6CG8"
}

const offer = {
  offerPrice: ethers.utils.parseUnits("5", DECIMALS.SIX),
  deadline: 3 * DAY, // in seconds
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
