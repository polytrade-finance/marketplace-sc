const { ethers } = require("hardhat");

async function main() {
  const treasuryWallet = "0xDf46a3793E2d12EC918c5De6deCA82669A030a8c";
  const feeWallet = "0x3AEDaC5c9D8723f78B446cD10Ee5ce7458E0198f";
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
  const token = TokenFactory.attach(
    "0xdd7fded184a005ba01f9f963ff2242136cf4f3eb"
  );

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
