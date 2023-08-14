const participantInfo = require("./onboard.json");
const {
  InitialSetup,
  CreateAsset,
  BuyFromBankA,
  BuyFromBankB,
  RelistAsset,
  SettleAsset,
} = require("./lib/utils.js");

async function main() {
  const { tokenContractAddress: bankATokenAddress } =
    participantInfo.accounts.bankA;
  const { tokenContractAddress: bankBTokenAddress } =
    participantInfo.accounts.bankB;
  const [addressBankA, , , buyerAddress] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.address)
    ),
  ];
  const [addressBankB] = [
    ...new Set(
      participantInfo.accounts.bankB.wallets.map((item) => item.address)
    ),
  ];
  const [, treasuryWalletPK, , buyerPK] = [
    ...new Set(
      participantInfo.accounts.bankA.wallets.map((item) => item.privateKey)
    ),
  ];
  const [addressBankBPK] = [
    ...new Set(
      participantInfo.accounts.bankB.wallets.map((item) => item.privateKey)
    ),
  ];

  const id = 601;

  await InitialSetup(
    treasuryWalletPK,
    buyerPK,
    addressBankBPK,
    bankATokenAddress,
    bankBTokenAddress
  );
  await CreateAsset(addressBankA, id, "10", "10000", 1);

  setTimeout(async function () {
    await BuyFromBankA(1, buyerPK, addressBankA, id, 3000);
  }, 3000);

  setTimeout(async function () {
    await RelistAsset(1, buyerPK, id, "11", 2000);
  }, 9000);

  setTimeout(async function () {
    await BuyFromBankB(1, addressBankBPK, buyerAddress, id, 2000);
  }, 12000);

  setTimeout(async function () {
    await SettleAsset(id, addressBankB);
    await SettleAsset(id, buyerAddress);
  }, 60000);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0xBFD351B1a15fdD876F644D7dfAB14cA3E6dcB7dE
// 0x5ca8233c2b5930a115a93dd55ca759daf843e36f
// 0x13741d56C55fF72b9E9878f689Dde120A11bDcf1
