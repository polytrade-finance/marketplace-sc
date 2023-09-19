const { ethers } = require("hardhat");
const { now } = require("./helpers");

const DECIMALS = {
  TWO: 2,
  SIX: 6,
  EIGHTEEN: 18,
};

const MarketplaceAccess = ethers.keccak256(
  ethers.toUtf8Bytes("MARKETPLACE_ROLE")
);

const OriginatorAccess = ethers.keccak256(
  ethers.toUtf8Bytes("ASSET_ORIGINATOR")
);

const AssetManagerAccess = ethers.keccak256(
  ethers.toUtf8Bytes("ASSET_MANAGER")
);

const DAY = 24n * 60n * 60n;
const YEAR = 360n * DAY;

const asset = {
  price: ethers.parseUnits("10", DECIMALS.SIX),
  dueDate: Number(new Date("2023-11-12").getTime() / 1000), // in seconds
  rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
  fractions: 10000,
};

const zeroPriceAsset = {
  price: 0,
  dueDate: Number(new Date("2023-11-12").getTime() / 1000), // in seconds
  rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
  fractions: 10000,
};

const nearSettleAsset = async () => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 100, // in seconds
    rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
    fractions: 10000,
  };
};

const nearSettleProperty = async () => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 100,
    fractions: 10000,
    size: 200,
    bathrooms: 2,
    rooms: 3,
    constructionDate: Number(new Date("2020-11-12").getTime() / 1000),
    country: "Italy",
    city: "Rome",
    location: "https://goo.gl/maps/bEBPrewmyJB8v6CG8",
  };
};

const property = {
  price: ethers.parseUnits("10", DECIMALS.SIX),
  dueDate: Number(new Date("2023-11-12").getTime() / 1000),
  fractions: 10000,
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
  zeroPriceAsset,
  nearSettleAsset,
  nearSettleProperty,
  property,
  offer,
  DECIMALS,
  MarketplaceAccess,
  OriginatorAccess,
  AssetManagerAccess,
};
