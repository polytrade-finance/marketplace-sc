const participantInfo = require("./onboard.json");
const {
  CreateProperty,
  BuyFromBankA,
  BuyFromBankB,
  RelistAsset,
  SettleProperty,
} = require("./lib/utils.js");

async function main() {
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
  const [, , , buyerPK] = [
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

  await CreateProperty(addressBankA, id, "10", 1);

  setTimeout(async function () {
    await BuyFromBankA(2, buyerPK, addressBankA, id, 5000);
  }, 3000);

  setTimeout(async function () {
    await RelistAsset(2, buyerPK, id, "11", 2500);
  }, 9000);

  setTimeout(async function () {
    await BuyFromBankB(2, addressBankBPK, buyerAddress, id, 2500);
  }, 12000);

  setTimeout(async function () {
    await SettleProperty(id, addressBankB, "11");
    await SettleProperty(id, buyerAddress, "11");
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
