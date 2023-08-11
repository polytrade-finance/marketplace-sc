const { ethers } = require("hardhat");
const participantInfo = require("./onboard.json");
const { property, asset } = require("../test/data");
require("dotenv").config();

const { MASTERCARD_ARCHIVAL_RPC } = process.env;

async function main() {
  const { tokenContractAddress: bankATokenAddress } =
    participantInfo.accounts.bankA;
  const { tokenContractAddress: bankBTokenAddress } =
    participantInfo.accounts.bankB;
  const [addressBankA, treW, feeW, buyerAddress] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.address)
    ),
  ];
  const [addressBankB] = [
    ...new Set(
      participantInfo.accounts.bankB.wallets.map((item) => item.address)
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
  const tokenB = TokenFactory.attach(bankBTokenAddress);

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
  await assetCollection
    .connect(buyerWallet)
    .setApprovalForAll(marketplace.getAddress(), true);
  await assetCollection.grantRole(MarketplaceAccess, marketplace.getAddress());
  await marketplace.setInitialFee(100);
  await marketplace.setBuyingFee(200);
  await marketplace.createProperty(
    addressBankA,
    1,
    asset.assetPrice,
    asset.dueDate,
    asset.minFraction,
    property
  );
  await marketplace.createAsset(
    addressBankA,
    3,
    ethers.parseUnits("10", 18),
    ethers.parseUnits("1000000", 2),
    1691660130,
    asset.minFraction
  );

  console.log(
    await marketplace
      .connect(buyerWallet)
      .buy(1, 3, asset.minFraction, addressBankA)
  );
  console.log(
    await marketplace
      .connect(buyerWallet)
      .relist(1, 3, ethers.parseUnits("11", 18), asset.minFraction)
  );
  console.log(await marketplace.buy(1, 3, asset.minFraction, buyerAddress));
  console.log(
    await marketplace.relist(
      1,
      3,
      ethers.parseUnits("12", 18),
      asset.minFraction
    )
  );
  console.log(
    await marketplace
      .connect(buyerWallet)
      .buy(1, 3, asset.minFraction, addressBankA)
  );
  console.log(await marketplace.settleAsset(3, buyerAddress));
  console.log(await marketplace.settleUnsold(1, 3));
  console.log(await marketplace.getRemainingReward(1, 3));
  console.log(await token.balanceOf(buyerAddress));
  console.log(await token.balanceOf(addressBankA));
  console.log(await token.balanceOf(addressBankB));
  console.log(await tokenB.transfer(addressBankB, 1000));
  console.log(await tokenB.balanceOf(addressBankA));
  console.log(await tokenB.balanceOf(addressBankB));
  console.log(addressBankA, treW, feeW, buyerAddress);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0x224e7a7bf97a6afdeA14F685a3E0E0361d964eCe
// 0x5ca8233c2b5930a115a93dd55ca759daf843e36f
// 0x11402e2FD5bd79b000a05AD303f74039D244b37e
