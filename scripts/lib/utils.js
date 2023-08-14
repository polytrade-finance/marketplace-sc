const { ethers } = require("hardhat");
const { asset, property } = require("../../test/data");
const { mtnAssetAddress, mtnMarketplaceAddress } = require("../data");
require("dotenv").config();

const { MASTERCARD_ARCHIVAL_RPC } = process.env;
const now = async () => {
  const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);

  return (await provider.getBlock(await provider.getBlockNumber())).timestamp;
};

const InitialSetup = async (
  treasuryWalletPK,
  buyerPK,
  bankBWalletPK,
  bankATokenAddress,
  bankBTokenAddress
) => {
  try {
    const MarketplaceAccess = ethers.keccak256(
      ethers.toUtf8Bytes("MARKETPLACE_ROLE")
    );

    const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);

    const treasuryWallet = new ethers.Wallet(treasuryWalletPK, provider);
    const buyerWallet = new ethers.Wallet(buyerPK, provider);
    const bankBWallet = new ethers.Wallet(bankBWalletPK, provider);

    const AssetFactory = await ethers.getContractFactory("Asset");
    const assetCollection = AssetFactory.attach(mtnAssetAddress);

    const TokenFactory = await ethers.getContractFactory("ERC20Token");
    const tokenA = TokenFactory.attach(bankATokenAddress);
    const tokenB = TokenFactory.attach(bankBTokenAddress);

    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    console.log(`Marketplace Address: ${mtnMarketplaceAddress}`);
    console.log(`Asset Contract Address: ${mtnAssetAddress} `);

    await tokenA.approve(marketplace.getAddress(), ethers.MaxUint256);
    console.log(
      `Approve marketplace for admin wallet on token A success! \u2705 `
    );

    await tokenA
      .connect(treasuryWallet)
      .approve(marketplace.getAddress(), ethers.MaxUint256);
    console.log(
      `Approve marketplace for treasury wallet (${treasuryWallet.address}) on token A success! \u2705 `
    );

    await tokenA
      .connect(buyerWallet)
      .approve(marketplace.getAddress(), ethers.MaxUint256);
    console.log(
      `Approve marketplace for buyer wallet (${buyerWallet.address}) on token A success! \u2705 `
    );

    await tokenB
      .connect(bankBWallet)
      .approve(marketplace.getAddress(), ethers.MaxUint256);
    console.log(
      `Approve marketplace for buyer wallet from bank B (${bankBWallet.address}) on token B success! \u2705 `
    );

    await assetCollection
      .connect(buyerWallet)
      .setApprovalForAll(marketplace.getAddress(), true);
    console.log(
      `Approve marketplace for buyer wallet (${buyerWallet.address}) on asset contract success! \u2705 `
    );

    await assetCollection
      .connect(bankBWallet)
      .setApprovalForAll(marketplace.getAddress(), true);
    console.log(
      `Approve marketplace for buyer wallet from bank B (${bankBWallet.address}) on asset contract success! \u2705 `
    );

    await assetCollection.grantRole(
      MarketplaceAccess,
      marketplace.getAddress()
    );
    console.log(
      `Grant marketplace access role for marketplace on asset contract success! \u2705 `
    );

    await marketplace.setInitialFee(100);
    console.log(`Set initial fee (1%) on marketpalce success! \u2705 `);

    await marketplace.setBuyingFee(200);
    console.log(`Set buying fee (2%) on marketpalce success! \u2705 `);

    await marketplace.addBankAccount(1, bankBTokenAddress);
    console.log(`Add bank B token addresss to marketplace success! \u2705 `);
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const CreateAsset = async (adminWalletAddress, id, price, apr, due) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const dueTimestamp = (await now()) + due * 60;

    const hash = (
      await marketplace.createAsset(
        adminWalletAddress,
        id,
        ethers.parseUnits(price, 18),
        ethers.parseUnits(apr, 2),
        dueTimestamp,
        asset.minFraction
      )
    ).hash;
    console.log(
      `\n Create Invoice (price: ${price}, apr: ${apr}%, Min. fraction: 10%, Due: ${dueTimestamp}) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const CreateProperty = async (adminWalletAddress, id, price, due) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const dueTimestamp = (await now()) + due * 60;

    const hash = (
      await marketplace.createProperty(
        adminWalletAddress,
        id,
        ethers.parseUnits(price, 18),
        dueTimestamp,
        asset.minFraction,
        property
      )
    ).hash;
    console.log(
      `\n Create Property (price: ${price}, Min. fraction: 10%, Due: ${dueTimestamp}) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const BuyFromBankA = async (assetType, buyerPK, owner, id, fractions) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);

    const buyerWallet = new ethers.Wallet(buyerPK, provider);

    const hash = (
      await marketplace
        .connect(buyerWallet)
        .buy(0, assetType, id, fractions, owner)
    ).hash;
    console.log(
      `\n Buy Invoice with ${
        buyerWallet.address
      } from Bank A (Asset id: ${id}, fractions: ${
        fractions / 100
      }%) success! \u2705 hash: ${hash} `
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const BuyFromBankB = async (assetType, buyerPK, owner, id, fractions) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);

    const buyerWallet = new ethers.Wallet(buyerPK, provider);

    const hash = (
      await marketplace
        .connect(buyerWallet)
        .buy(1, assetType, id, fractions, owner)
    ).hash;
    console.log(
      `\n Buy Invoice with ${
        buyerWallet.address
      } from Bank B (Asset id: ${id}, fractions: ${
        fractions / 100
      }%) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const RelistAsset = async (assetType, ownerPK, id, salePrice, fractions) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);

    const ownerWallet = new ethers.Wallet(ownerPK, provider);

    const hash = (
      await marketplace
        .connect(ownerWallet)
        .relist(assetType, id, ethers.parseUnits(salePrice, 18), fractions)
    ).hash;
    console.log(
      `\n Relist Invoice with ${
        ownerWallet.address
      } (Asset id: ${id}, Sale price: ${salePrice}, Min. fraction to buy: ${
        fractions / 100
      }%) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const SettleAsset = async (id, owner) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const hash = (await marketplace.settleAsset(id, owner)).hash;

    console.log(
      `\n Settle Invoice for ${owner} owner (Asset id: ${id}) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

const SettleProperty = async (id, owner, amount) => {
  try {
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = Marketplace.attach(mtnMarketplaceAddress);

    const hash = (
      await marketplace.settleProperty(id, owner, ethers.parseUnits(amount, 18))
    ).hash;

    console.log(
      `\n Settle Property for ${owner} owner (Asset id: ${id}, Settle amount: ${amount}) success! \u2705 hash: ${hash}`
    );
  } catch (error) {
    console.log(error);
    throw new Error(error);
  }
};

module.exports = {
  InitialSetup,
  CreateAsset,
  CreateProperty,
  BuyFromBankA,
  BuyFromBankB,
  RelistAsset,
  SettleAsset,
  SettleProperty,
};
