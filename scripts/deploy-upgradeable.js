const { ethers, upgrades } = require("hardhat");
const { treasuryWallet, feeWallet } = require("./data");

async function main() {
  const MarketplaceAccess = ethers.keccak256(
    ethers.toUtf8Bytes("MARKETPLACE_ROLE")
  );

  const AssetManagerAccess = ethers.keccak256(
    ethers.toUtf8Bytes("ASSET_MANAGER")
  );

  const AssetFactory = await ethers.getContractFactory("BaseAsset");
  const asset = await AssetFactory.deploy(
    "PolytradeAssets",
    "PRWA",
    "2.3",
    "https://polytrade.app/"
  );
  await asset.waitForDeployment();

  console.log(await asset.getAddress());

  const TokenFactory = await ethers.getContractFactory("MockERC721");
  const token = await TokenFactory.deploy("NFT", "NFT", "ipfs");

  console.log(await token.getAddress());

  const FeeManager = await ethers.getContractFactory("FeeManager");
  const feeManager = await FeeManager.deploy(0, 0, feeWallet);
  await feeManager.waitForDeployment();

  console.log(await feeManager.getAddress());

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.deployProxy(Marketplace, [
    await asset.getAddress(),
    await feeManager.getAddress(),
  ]);
  await marketplace.waitForDeployment();

  console.log(await marketplace.getAddress());

  const InvoiceAssetFactory = await ethers.getContractFactory("InvoiceAsset");
  const invoiceAsset = await upgrades.deployProxy(InvoiceAssetFactory, [
    await asset.getAddress(),
    treasuryWallet,
    await marketplace.getAddress(),
  ]);
  await invoiceAsset.waitForDeployment();

  console.log(await invoiceAsset.getAddress());

  const PropertyAssetFactory = await ethers.getContractFactory("PropertyAsset");
  const propertyAsset = await upgrades.deployProxy(PropertyAssetFactory, [
    await asset.getAddress(),
    treasuryWallet,
  ]);
  await propertyAsset.waitForDeployment();

  console.log(await propertyAsset.getAddress());

  const WrapperFactory = await ethers.getContractFactory("WrappedAsset");
  const wrapperAsset = await WrapperFactory.deploy(await asset.getAddress());
  await wrapperAsset.waitForDeployment();

  console.log(await wrapperAsset.getAddress());

  await token.approve(marketplace.getAddress(), ethers.MaxUint256);

  await asset.grantRole(AssetManagerAccess, invoiceAsset.getAddress());

  await asset.grantRole(AssetManagerAccess, propertyAsset.getAddress());

  await asset.grantRole(AssetManagerAccess, wrapperAsset.getAddress());

  await invoiceAsset.grantRole(MarketplaceAccess, marketplace.getAddress());

  await asset.setApprovalForAll(marketplace.getAddress(), true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});
