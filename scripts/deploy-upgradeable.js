const { ethers, upgrades } = require("hardhat");
const { tokenAddress, treasuryWallet, feeWallet } = require("./data");

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

  const TokenFactory = await ethers.getContractFactory("ERC20Token");
  const token = TokenFactory.attach(tokenAddress);

  console.log(await token.getAddress());

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

// Asset 0xef0bABAdd9DfF3E4C3A85E904fe669891Cb6Dd80
// Token 0xdd7fded184a005ba01f9f963ff2242136cf4f3eb
// Marketplace 0x34753E78415cD88176688449D7d7812f97108A88
// Invoice 0x60059c6bBe88CaD480eB0465Ec9ED3CbA1a91C6e
// Property 0x11C23AADD1E01D2eC7044Ff5259ad7aD18502c16
// Wrapper 0x1C807B6378Ed18A01792749222a509F2Aee1DE08
// NFT 0xCCa859b22f3FD6544CbE088dDf3b5154abAA8748
