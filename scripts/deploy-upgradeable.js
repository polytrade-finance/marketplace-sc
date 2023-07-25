const { ethers } = require("hardhat");
const hre = require("hardhat");
const { tokenAddress, treasuryWallet, feeWallet } = require("./data");

async function main() {
  const MarketplaceAccess = ethers.keccak256(
    ethers.toUtf8Bytes("MARKETPLACE_ROLE")
  );
  const AssetFactory = await ethers.getContractFactory("Asset");
  const asset = await AssetFactory.deploy(
    "PolytradeAssetManager",
    "PAM",
    "https://polytrade.finance"
  );
  await asset.waitForDeployment();

  console.log(asset.getAddress());

  const TokenFactory = await ethers.getContractFactory("Token");
  const token = TokenFactory.attach(tokenAddress);

  console.log(await token.getAddress());

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(
    asset.getAddress(),
    token.getAddress(),
    treasuryWallet,
    feeWallet
  );
  await marketplace.waitForDeployment();

  console.log(await marketplace.getAddress());

  await token.approve(marketplace.getAddress(), ethers.MaxUint256);
  await asset.grantRole(MarketplaceAccess, marketplace.getAddress());
  await marketplace.setInitialFee(100);
  await marketplace.setBuyingFee(200);

  await hre.run("verify:verify", {
    address: asset.getAddress(),
    constructorArguments: [
      "PolytradeAssetManager",
      "PAM",
      "https://polytrade.finance",
    ],
  });

  await hre.run("verify:verify", {
    address: marketplace.getAddress(),
    constructorArguments: [
      asset.getAddress(),
      token.getAddress(),
      treasuryWallet,
      feeWallet,
    ],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});
