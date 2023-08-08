const { ethers, upgrades } = require("hardhat");
const participantInfo = require("./onboard.json");
const { property, asset } = require("../test/data");
require("dotenv").config();

const { MASTERCARD_ARCHIVAL_RPC } = process.env;

async function main() {
  const { tokenContractAddress: bankATokenAddress } =
    participantInfo.accounts.bankA;
  const [addressBankA, treasuryWalletBankA, feeWalletBankA, addressBuyer] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.address)
    ),
  ];
  const [, treasuryWalletPK, , buyerPK] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.privateKey)
    ),
  ];
  // const [{ address: feeWalletBankA }] = participantInfo.accounts.bankA.wallets;
  const provider = new ethers.JsonRpcProvider(MASTERCARD_ARCHIVAL_RPC);
  const treasuryWallet = new ethers.Wallet(treasuryWalletPK, provider);
  const buyerWallet = new ethers.Wallet(buyerPK, provider);

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
  // const asset = await AssetFactory.deploy(
  //   "PolytradeAssetManager",
  //   "PAM",
  //   "2.2",
  //   "https://polytrade.finance/"
  // );
  // await asset.waitForDeployment();
  // console.log(await asset.getAddress());

  const TokenFactory = await ethers.getContractFactory("ERC20Token");
  const token = TokenFactory.attach(bankATokenAddress);
  // console.log(await token.getAddress());

  // const balance = await token.balanceOf(addressBankA);
  // console.log(`Endpoint connection check for contract ${bankATokenAddress} and address ${addressBankA}: success! \u2705 `);
  // console.log(`Balance is ${ethers.formatUnits(balance, 18)}`);

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = Marketplace.attach(
    "0xb78aA32CcEee2B2F1B51B945a68a26cd71a4bD23"
  );
  // const marketplace = await upgrades.deployProxy(Marketplace, [await asset.getAddress(), await token.getAddress(), treasuryWalletBankA, feeWalletBankA]);
  // await marketplace.waitForDeployment();
  // console.log(await marketplace.getAddress());

  // await token.approve(marketplace.getAddress(), ethers.MaxUint256);
  // await asset.grantRole(MarketplaceAccess, marketplace.getAddress());
  // await marketplace.setInitialFee(100);
  // await marketplace.setBuyingFee(200);
  console.log(await marketplace.getAssetInfo(1, 1));

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0x72cC7f9D20DA678dfA7D72EF016d973b45f66741
// 0xdd7fded184a005ba01f9f963ff2242136cf4f3eb
// 0x4Fa8876e4ea64E86B0Ea6a29812728D763E5B1FE
