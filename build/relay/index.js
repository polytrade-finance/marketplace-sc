"use strict";

const ethers = require("ethers");
const require$$0 = require("defender-relay-client/lib/ethers");

function _interopDefaultLegacy(e) {
  return e && typeof e === "object" && "default" in e ? e : { default: e };
}

const ethers__default = /* #__PURE__ */ _interopDefaultLegacy(ethers);
const require$$0__default = /* #__PURE__ */ _interopDefaultLegacy(require$$0);

/**
 * ABI of the MinimalForwarder contract
 */
const ForwarderAbi$1 = [
  { inputs: [], stateMutability: "nonpayable", type: "constructor" },
  {
    inputs: [
      {
        components: [
          { internalType: "address", name: "from", type: "address" },
          { internalType: "address", name: "to", type: "address" },
          { internalType: "uint256", name: "value", type: "uint256" },
          { internalType: "uint256", name: "gas", type: "uint256" },
          { internalType: "uint256", name: "nonce", type: "uint256" },
          { internalType: "bytes", name: "data", type: "bytes" },
        ],
        internalType: "struct MinimalForwarder.ForwardRequest",
        name: "req",
        type: "tuple",
      },
      { internalType: "bytes", name: "signature", type: "bytes" },
    ],
    name: "execute",
    outputs: [
      { internalType: "bool", name: "", type: "bool" },
      { internalType: "bytes", name: "", type: "bytes" },
    ],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "from", type: "address" }],
    name: "getNonce",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        components: [
          { internalType: "address", name: "from", type: "address" },
          { internalType: "address", name: "to", type: "address" },
          { internalType: "uint256", name: "value", type: "uint256" },
          { internalType: "uint256", name: "gas", type: "uint256" },
          { internalType: "uint256", name: "nonce", type: "uint256" },
          { internalType: "bytes", name: "data", type: "bytes" },
        ],
        internalType: "struct MinimalForwarder.ForwardRequest",
        name: "req",
        type: "tuple",
      },
      { internalType: "bytes", name: "signature", type: "bytes" },
    ],
    name: "verify",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "view",
    type: "function",
  },
];

const forwarder = {
  ForwarderAbi: ForwarderAbi$1,
};

const MinimalForwarder = "0x3214780Ccc7325503F474b5D73F46950A5c57ee2";
const Marketplace = "0x23F3666f661D3Da0Fc28d0bec8cC95D8d758D9a5";
const require$$2 = {
  MinimalForwarder,
  Marketplace,
};

const { DefenderRelaySigner, DefenderRelayProvider } =
  require$$0__default.default;

const { ForwarderAbi } = forwarder;
const ForwarderAddress = require$$2.MinimalForwarder;
const MarketplaceAddress = require$$2.Marketplace;

async function relay(forwarder, request, signature, whitelist) {
  // Decide if we want to relay this request based on a whitelist
  const accepts = !whitelist || whitelist.includes(request.to);
  if (!accepts) throw new Error(`Rejected request to ${request.to}`);

  // Validate request on the forwarder contract
  const valid = await forwarder.verify(request, signature);
  if (!valid) throw new Error(`Invalid request`);

  // Send meta-tx through relayer to the forwarder contract
  const gasLimit = (parseInt(request.gas) + 50000).toString();
  return await forwarder.execute(request, signature, { gasLimit });
}

async function handler(event) {
  // Parse webhook payload
  if (!event.request || !event.request.body) throw new Error(`Missing payload`);
  const { request, signature } = event.request.body;
  console.log(`Relaying`, request);

  // Initialize Relayer provider and signer, and forwarder contract
  const credentials = { ...event };
  const provider = new DefenderRelayProvider(credentials);
  const signer = new DefenderRelaySigner(credentials, provider, {
    speed: "fast",
  });
  const forwarder = new ethers__default.default.Contract(
    ForwarderAddress,
    ForwarderAbi,
    signer
  );
  const whitelist = [MarketplaceAddress];

  // Relay transaction!
  const tx = await relay(forwarder, request, signature, whitelist);
  console.log(`Sent meta-tx: ${tx.hash}`);
  return { txHash: tx.hash };
}

const relay_1 = {
  handler,
  relay,
};

module.exports = relay_1;
