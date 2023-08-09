const { ethers } = require("hardhat");
const participantInfo = require("./onboard.json");
const { property, asset } = require("../test/data");
require("dotenv").config();

const { MASTERCARD_ARCHIVAL_RPC } = process.env;

async function main() {
  const { tokenContractAddress: bankATokenAddress } =
    participantInfo.accounts.bankA;
  const [addressBankA, , ,] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.address)
    ),
  ];
  const [, treasuryWalletPK, , buyerPK] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.privateKey)
    ),
  ];

  const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);
  const treasuryWallet = new ethers.Wallet(treasuryWalletPK, provider);
  const buyerWallet = new ethers.Wallet(buyerPK, provider);

  const MarketplaceAccess = ethers.keccak256(
    ethers.toUtf8Bytes("MARKETPLACE_ROLE")
  );

  const AssetFactory = await ethers.getContractFactory("Asset");
  const assetCollection = AssetFactory.attach(
    "0x224e7a7bf97a6afdeA14F685a3E0E0361d964eCe"
  );

  const TokenFactory = await ethers.getContractFactory("ERC20Token");
  const token = TokenFactory.attach(bankATokenAddress);

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = Marketplace.attach(
    "0x11402e2FD5bd79b000a05AD303f74039D244b37e"
  );

  await token.approve(marketplace.getAddress(), ethers.MaxUint256);
  await token
    .connect(treasuryWallet)
    .approve(marketplace.getAddress(), ethers.MaxUint256);
  await token
    .connect(buyerWallet)
    .approve(marketplace.getAddress(), ethers.MaxUint256);
  await assetCollection.setApprovalForAll(marketplace.getAddress(), true);
  await assetCollection.grantRole(MarketplaceAccess, marketplace.getAddress());
  await marketplace.setInitialFee(100);
  await marketplace.setBuyingFee(200);
  await marketplace.createAsset(
    addressBankA,
    1,
    asset.assetPrice,
    asset.rewardApr,
    asset.dueDate,
    asset.minFraction
  );
  await marketplace.createProperty(
    addressBankA,
    1,
    asset.assetPrice,
    asset.dueDate,
    asset.minFraction,
    property
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0x224e7a7bf97a6afdeA14F685a3E0E0361d964eCe
// 0x5ca8233c2b5930a115a93dd55ca759daf843e36f
// 0x11402e2FD5bd79b000a05AD303f74039D244b37e
