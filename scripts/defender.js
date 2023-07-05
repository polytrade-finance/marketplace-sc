const {
  DefenderRelayProvider,
  DefenderRelaySigner,
} = require("@openzeppelin/defender-relay-client/lib/ethers");
const { ethers } = require("hardhat");
const { ForwarderAbi } = require("./forwarder");
const { buildTypedData } = require("./signer");
const ethSigUtil = require("@metamask/eth-sig-util");

async function main() {
  const { RELAYER_API_KEY, RELAYER_SECRET_KEY, TESTNET_PRIVATE_KEY } =
    process.env;
  const from = new ethers.Wallet(TESTNET_PRIVATE_KEY).address;
  const credentials = {
    apiKey: RELAYER_API_KEY,
    apiSecret: RELAYER_SECRET_KEY,
  };
  const provider = new DefenderRelayProvider(credentials);
  const signer = new DefenderRelaySigner(credentials, provider, {
    speed: "fast",
  });

  const Forwarder = await ethers.getContractFactory("MinimalForwarder");
  const forwarder = await Forwarder.attach(
    "0x3214780Ccc7325503F474b5D73F46950A5c57ee2"
  );

  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.attach(
    "0x23F3666f661D3Da0Fc28d0bec8cC95D8d758D9a5"
  );
  await marketplace.deployed();

  const forward = new ethers.Contract(forwarder.address, ForwarderAbi, signer);
  const data = marketplace.interface.encodeFunctionData("setBuyingFee", [2000]);
  const input = {
    from,
    to: marketplace.address,
    data,
  };
  const nonce = await forwarder
    .getNonce(from)
    .then((nonce) => nonce.toString());
  const request = { value: 0, gas: 1e6, nonce, ...input };
  const toSign = await buildTypedData(forward, request);
  const signature = ethSigUtil.signTypedData({
    data: toSign,
    privateKey: TESTNET_PRIVATE_KEY,
    version: "V4",
  });
  const result = await forward.functions.verify(request, signature);
  console.log(result);
  const tx = await forward.functions.execute(request, signature);
  console.log(tx);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// asset: 0xd4474b7f6e3bC80E6112179D52BE291A984eE0c0
// market: 0x23F3666f661D3Da0Fc28d0bec8cC95D8d758D9a5
// forwarder: 0x3214780Ccc7325503F474b5D73F46950A5c57ee2
