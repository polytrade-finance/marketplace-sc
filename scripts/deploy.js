const { ethers } = require("hardhat");
const { tokenAddress, treasuryWallet, feeWallet } = require("./data");

async function main() {
  const MarketplaceAccess = ethers.utils.keccak256(
    ethers.utils.toUtf8Bytes("MARKETPLACE_ROLE")
  );
  const AssetFactory = await ethers.getContractFactory("Asset");
  const asset = await AssetFactory.deploy(
    "PolytradeAssetManager",
    "PAM",
    "https://polytrade.finance"
  );
  await asset.deployed();

  console.log(asset.address);

  const TokenFactory = await ethers.getContractFactory("Token");
  const token = TokenFactory.attach(tokenAddress);

  console.log(token.address);

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    asset.address,
    token.address,
    treasuryWallet,
    feeWallet
  );
  await marketplace.deployed();

  console.log(marketplace.address);

  await token.approve(marketplace.address, ethers.constants.MaxUint256);
  await asset.grantRole(MarketplaceAccess, marketplace.address);
  await marketplace.setInitialFee(100);
  await marketplace.setBuyingFee(200);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});
