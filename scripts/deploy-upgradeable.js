const { ethers, upgrades } = require("hardhat");
const { tokenAddress, treasuryWallet, feeWallet } = require("./data");

async function main() {
  const MarketplaceAccess = ethers.keccak256(
    ethers.toUtf8Bytes("MARKETPLACE_ROLE")
  );

  const AssetManagerAccess = ethers.keccak256(
    ethers.toUtf8Bytes("ASSET_MANAGER")
  );

  // const AssetFactory = await ethers.getContractFactory("BaseAsset");
  // const asset = await AssetFactory.deploy(
  //   "PolytradeRealWorldAssets",
  //   "PRWA",
  //   "2.3",
  //   "https://polytrade.finance/"
  // );
  // await asset.waitForDeployment();

  // console.log("Asset:", await asset.getAddress());

  // const TokenFactory = await ethers.getContractFactory("MockERC20");
  // const token = TokenFactory.attach(tokenAddress);
  // // const token = await TokenFactory.deploy(
  // //   "StableCoin",
  // //   "USDC",
  // //   6,
  // //   "0x4aAc55CcF940Cc3Bbbbc82f0a8537002583a42A8",
  // //   1_000_000
  // // );

  // // await token.waitForDeployment();

  // console.log("Token:", await token.getAddress());

  // const FeeManager = await ethers.getContractFactory("FeeManager");
  // const feeManager = await FeeManager.deploy(50, 50, feeWallet);
  // await feeManager.waitForDeployment();

  // const Marketplace = await ethers.getContractFactory("Marketplace");
  // const marketplace = await upgrades.deployProxy(Marketplace, [
  //   await asset.getAddress(),
  //   await feeManager.getAddress(),
  // ]);
  // await marketplace.waitForDeployment();

  // console.log("Marketplace:", await marketplace.getAddress());

  const InvoiceAssetFactory = await ethers.getContractFactory("InvoiceAsset");
  const invoiceAsset = await upgrades.deployProxy(InvoiceAssetFactory, [
    "0x0Cb86161ca717C05c208D870d753C9cF0C13A795",
    treasuryWallet,
    "0x47B74E3d625632026C1676d9cf777A67af0aA9E1",
  ]);
  await invoiceAsset.waitForDeployment();

  console.log("Invoice:", await invoiceAsset.getAddress());

  // const PropertyAssetFactory = await ethers.getContractFactory("PropertyAsset");
  // const propertyAsset = await upgrades.deployProxy(PropertyAssetFactory, [
  //   await asset.getAddress(),
  //   treasuryWallet,
  // ]);
  // await propertyAsset.waitForDeployment();

  // console.log("Property:", await propertyAsset.getAddress());

  // const WrapperFactory = await ethers.getContractFactory("WrappedAsset");
  // const wrapperAsset = await WrapperFactory.deploy(await asset.getAddress());
  // await wrapperAsset.waitForDeployment();

  // console.log("Wrapper:", await wrapperAsset.getAddress());

  // await token.approve(marketplace.getAddress(), ethers.MaxUint256);
  // // await token.approve(
  // //   "0x629cDcCB2d57e38F764C06750e340ACBD2041b68",
  // //   ethers.MaxUint256
  // // );

  // await asset.grantRole(AssetManagerAccess, invoiceAsset.getAddress());

  // await asset.grantRole(AssetManagerAccess, propertyAsset.getAddress());

  // await asset.grantRole(AssetManagerAccess, wrapperAsset.getAddress());

  // await asset.grantRole(MarketplaceAccess, marketplace.getAddress());

  await invoiceAsset.grantRole(
    MarketplaceAccess,
    "0x47B74E3d625632026C1676d9cf777A67af0aA9E1"
  );

  await invoiceAsset.grantRole(
    AssetManagerAccess,
    "0x47B74E3d625632026C1676d9cf777A67af0aA9E1"
  );

  // await asset.setApprovalForAll(marketplace.getAddress(), true);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0xc3978e77aD488D172192F0059AF691D93EaB3701
// 0xdd7fded184a005ba01f9f963ff2242136cf4f3eb
// 0xB707aDA168f75dA38ee5e9E52370cF099531f18d
// 0x629cDcCB2d57e38F764C06750e340ACBD2041b68
// 0xd2C4301BBA81CAf3Ef117252657412B07CEe0C82
// 0xaD01fd63f7D619a09D7D3dc029618b928C1Dcb84
