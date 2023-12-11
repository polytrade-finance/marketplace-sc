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
    "PolytradeRealWorldAssets",
    "PRWA",
    "2.3",
    "https://polytrade.finance/"
  );
  await asset.waitForDeployment();

  console.log(await asset.getAddress());

  const WrapperFactory = await ethers.getContractFactory("WrappedAsset");
  const wrapperAsset = await WrapperFactory.deploy(await asset.getAddress());
  await wrapperAsset.waitForDeployment();

  console.log(await wrapperAsset.getAddress());

  // const TokenFactory = await ethers.getContractFactory("ERC20Token");
  // const token = TokenFactory.attach(tokenAddress);

  // console.log(await token.getAddress());

  const FeeManager = await ethers.getContractFactory("FeeManager");
  const feeManager = await FeeManager.deploy(100, 200, feeWallet);
  await feeManager.waitForDeployment();

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

// Polygon
// BaseAsset 0x6bD42F82dBD545eD95d861CAe21013b8E00bbf83
// Wrapper 0xCfD4d25cBeED0e61C118938ff3c55a076b03D439
// Marketplace 0x596C89d5DA9368F33E22e2A783a1a6BC097278Be
// Invoice 0xD3F665E0bF7F4aeA50B4ee7C1CDF6d827C0654df
// Property 0x97463C65642e62f728D5d73F7A055097721D4347
