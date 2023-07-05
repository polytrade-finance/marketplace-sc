const { ethers } = require("hardhat");
const { readFileSync, writeFileSync } = require("fs");
const { buildTypedData } = require("../signer");
const ethSigUtil = require("@metamask/eth-sig-util");

function getInstance(name) {
  const address = JSON.parse(readFileSync("deploy.json"))[name];
  if (!address) throw new Error(`Contract ${name} not found in deploy.json`);
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const forwarder = await getInstance("MinimalForwarder");
  const marketplace = await getInstance("Marketplace");

  const { TESTNET_PRIVATE_KEY } = process.env;
  const from = new ethers.Wallet(TESTNET_PRIVATE_KEY).address;

  const data = marketplace.interface.encodeFunctionData("setBuyingFee", [4000]);
  const input = {
    from,
    to: marketplace.address,
    data,
  };
  const nonce = await forwarder
    .getNonce(from)
    .then((nonce) => nonce.toString());
  const request = { value: 0, gas: 1e6, nonce, ...input };
  const toSign = await buildTypedData(forwarder, request);
  const signature = ethSigUtil.signTypedData({
    data: toSign,
    privateKey: TESTNET_PRIVATE_KEY,
    version: "V4",
  });

  console.log(`Signing tx as ${from}...`);

  writeFileSync(
    "tmp/request.json",
    JSON.stringify({ signature, request }, null, 2)
  );
  console.log(`Signature: `, signature);
  console.log(`Request: `, request);
}

if (require.main === module) {
  main().catch((error) => {
    throw new Error(error);
  });
}
