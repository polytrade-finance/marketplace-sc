const { ethers, upgrades } = require("hardhat");
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
    "2.2",
    "https://polytrade.finance"
  );
  await asset.waitForDeployment();

  console.log(await asset.getAddress());

  const TokenFactory = await ethers.getContractFactory("ERC20Token");
  const token = TokenFactory.attach(tokenAddress);

  console.log(await token.getAddress());

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.deployProxy(Marketplace, [
    await asset.getAddress(),
    await token.getAddress(),
    treasuryWallet,
    feeWallet,
  ]);
  await marketplace.waitForDeployment();

  console.log(await marketplace.getAddress());

  await token.approve(marketplace.getAddress(), ethers.MaxUint256);
  await asset.grantRole(MarketplaceAccess, marketplace.getAddress());
  await asset.setApprovalForAll(marketplace.getAddress(), true);
  await marketplace.setInitialFee(100);
  await marketplace.setBuyingFee(200);

  await hre.run("verify:verify", {
    address: await asset.getAddress(),
    constructorArguments: [
      "PolytradeAssetManager",
      "PAM",
      "2.2",
      "https://polytrade.finance",
    ],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0x72cC7f9D20DA678dfA7D72EF016d973b45f66741
// 0xdd7fded184a005ba01f9f963ff2242136cf4f3eb
// 0x4Fa8876e4ea64E86B0Ea6a29812728D763E5B1FE
