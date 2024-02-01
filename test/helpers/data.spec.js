const { ethers } = require("hardhat");
const { now } = require("./time");

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

const createList = async (salePrice, listedFractions, minFraction, token) => {
  return {
    salePrice,
    listedFractions,
    minFraction,
    token,
  };
};

const createAsset = async (token) => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 7890000, // add 3 months
    rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
    fractions: 10000n,
    settlementToken: token,
  };
};

const zeroPriceAsset = async (token) => {
  return {
    price: 0,
    dueDate: (await now()) + 7890000, // add 3 months
    rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
    fractions: 10000n,
    settlementToken: token,
  };
};

const nearSettleAsset = async (token) => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 100, // in seconds
    rewardApr: ethers.parseUnits("10", DECIMALS.TWO), // with 2 decimals
    fractions: 10000n,
    settlementToken: token,
  };
};

const nearSettleProperty = async (token) => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 100,
    fractions: 10000n,
    settlementToken: token,
  };
};

const createProperty = async (token) => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    dueDate: (await now()) + 7890000, // add 3 months
    fractions: 10000n,
    settlementToken: token,
  };
};

const offer = {
  offerPrice: ethers.parseUnits("5", DECIMALS.SIX),
  deadline: 3n * DAY, // in seconds
};

const SandTokenId =
  "53343204100803765692379285688171671302437967278842259121980540727211386210304";

const EnsTokenId =
  "88702082417345488823430055150938155509739316843104657636167181501132256854145";

module.exports = {
  EnsTokenId,
  SandTokenId,
  DAY,
  YEAR,
  createAsset,
  createList,
  zeroPriceAsset,
  nearSettleAsset,
  nearSettleProperty,
  createProperty,
  offer,
  DECIMALS,
  MarketplaceAccess,
  OriginatorAccess,
  AssetManagerAccess,
};
