const { ethers, upgrades } = require("hardhat");
const participantInfo = require("./onboard.json");

async function main() {
  const { tokenContractAddress: bankATokenAddress } =
    participantInfo.accounts.bankA;
  const [, treasuryWalletBankA, feeWalletBankA] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.address)
    ),
  ];

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
  const token = TokenFactory.attach(bankATokenAddress);
  console.log(await token.getAddress());

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.deployProxy(Marketplace, [
    await asset.getAddress(),
    await token.getAddress(),
    treasuryWalletBankA,
    feeWalletBankA,
  ]);
  await marketplace.waitForDeployment();
  console.log(await marketplace.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0xb571DDa4804B4e8c99A8452535fB63F93E694e01
// 0x5ca8233c2b5930a115a93dd55ca759daf843e36f
// 0x1A0EAF3e98f266c3c4ebA74cE912ddB54A0B6e2A
