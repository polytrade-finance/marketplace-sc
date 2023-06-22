const ethSigUtil = require("@metamask/eth-sig-util");
const { expect } = require("chai");
const { BigNumber } = require("ethers");
const { keccak256, recoverAddress, toUtf8Bytes } = require("ethers/lib/utils");

const hexRegex = /[A-Fa-fx]/g;

const toBN = (n) => BigNumber.from(toHex(n, 0));

const toHex = (n, numBytes) => {
  const asHexString = BigNumber.isBigNumber(n)
    ? n.toHexString().slice(2)
    : typeof n === "string"
    ? hexRegex.test(n)
      ? n.replace(/0x/, "")
      : Number(n).toString(16)
    : Number(n).toString(16);
  return `0x${asHexString.padStart(numBytes * 2, "0")}`;
};

const calculateOfferHash = (params) => {
  const OfferTypeString =
    "CounterOffer(address owner,address offeror,uint256 offerPrice,uint256 assetId,uint256 nonce,uint256 deadline)";

  const offerTypeHash = keccak256(toUtf8Bytes(OfferTypeString));

  const derivedOfferHash = keccak256(
    "0x" +
      [
        offerTypeHash.slice(2),
        params.owner.slice(2).padStart(64, "0"),
        params.offeror.slice(2).padStart(64, "0"),
        toBN(params.offerPrice).toHexString().slice(2).padStart(64, "0"),
        toBN(params.assetId).toHexString().slice(2).padStart(64, "0"),
        toBN(params.nonce).toHexString().slice(2).padStart(64, "0"),
        toBN(params.deadline).toHexString().slice(2).padStart(64, "0"),
      ].join("")
  );

  return derivedOfferHash;
};

const validateRecoveredAddress = (
  expectAddress,
  domainSeparator,
  hash,
  signature
) => {
  const digest = keccak256(`0x1901${domainSeparator.slice(2)}${hash.slice(2)}`);
  const recoveredAddress = recoverAddress(digest, signature);
  expect(recoveredAddress).to.be.equal(expectAddress);
};

async function domainSeparatorCal(name, version, chainId, verifyingContract) {
  const EIP712Domain = [
    { name: "name", type: "string" },
    { name: "version", type: "string" },
    { name: "chainId", type: "uint256" },
    { name: "verifyingContract", type: "address" },
  ];
  return (
    "0x" +
    ethSigUtil.TypedDataUtils.hashStruct(
      "EIP712Domain",
      { name, version, chainId, verifyingContract },
      { EIP712Domain },
      "V4"
    ).toString("hex")
  );
}

module.exports = {
  toBN,
  toHex,
  calculateOfferHash,
  validateRecoveredAddress,
  domainSeparatorCal,
};
