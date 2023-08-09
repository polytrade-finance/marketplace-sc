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

// 0x224e7a7bf97a6afdeA14F685a3E0E0361d964eCe
// 0x5ca8233c2b5930a115a93dd55ca759daf843e36f
// 0x11402e2FD5bd79b000a05AD303f74039D244b37e
