const { ethers } = require("hardhat");
const { DECIMALS } = require("./helpers/data.spec");

// Constants (Replace with actual values)
const CHAIN_ID = 80002; // Example: Polygon Amoy Testnet Chain ID
const contractAddress = "0x4475026B1eFaC920a4984B1749085AaFB11d63be"; // Replace with actual invoice contract address

const ABI = [
  {
    inputs: [
      { internalType: "string", name: "name_", type: "string" },
      { internalType: "string", name: "symbol_", type: "string" },
      { internalType: "uint8", name: "decimals_", type: "uint8" },
      { internalType: "address", name: "receiver_", type: "address" },
      { internalType: "uint256", name: "totalSupply_", type: "uint256" },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "spender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "from", type: "address" },
      { indexed: true, internalType: "address", name: "to", type: "address" },
      {
        indexed: false,
        internalType: "uint256",
        name: "value",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      { internalType: "address", name: "owner", type: "address" },
      { internalType: "address", name: "spender", type: "address" },
    ],
    name: "allowance",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [{ internalType: "address", name: "account", type: "address" }],
    name: "balanceOf",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "decimals",
    outputs: [{ internalType: "uint8", name: "", type: "uint8" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "subtractedValue", type: "uint256" },
    ],
    name: "decreaseAllowance",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "spender", type: "address" },
      { internalType: "uint256", name: "addedValue", type: "uint256" },
    ],
    name: "increaseAllowance",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [{ internalType: "string", name: "", type: "string" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [{ internalType: "uint256", name: "", type: "uint256" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "to", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transfer",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { internalType: "address", name: "from", type: "address" },
      { internalType: "address", name: "to", type: "address" },
      { internalType: "uint256", name: "amount", type: "uint256" },
    ],
    name: "transferFrom",
    outputs: [{ internalType: "bool", name: "", type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
];

// Function to generate invoiceMainId
async function generateInvoiceMainId(nonce) {
  const invoiceMainId = BigInt(
    ethers.solidityPackedKeccak256(
      ["uint256", "address", "address", "uint256"],
      [CHAIN_ID, contractAddress, contractAddress, nonce]
    )
  );

  return invoiceMainId;
}

async function now() {
  return (
    await ethers.provider.getBlock(await ethers.provider.getBlockNumber())
  ).timestamp;
}

const createAsset = async (token) => {
  return {
    price: ethers.parseUnits("10", DECIMALS.SIX),
    tenure: 1,
    invoiceDate: await now(), // add 1 day
    dueDate: (await now()) + 60 * 60 * 24, // add 1 day
    dueAmount: ethers.parseUnits("12", DECIMALS.SIX),
    fractions: 10n,
    settlementToken: token,
  };
};

// Example usage
(async () => {
  const nonce = 0; // Replace with actual nonce (from contract)
  const invoiceMainId = await generateInvoiceMainId(nonce);
  console.log("Invoice Main ID:", invoiceMainId.toString());
  const asset = await createAsset("");
  console.log(asset);
  const provider = new ethers.JsonRpcProvider(
    "https://rpc-amoy.polygon.technology/"
  );
  const privateKey =
    "1680c147d193e9967104c3cd904b96853e5a867dcea953ffe0aafe95b21aa235"; // replace with env var if needed
  // const privateKey =
  //   "192686bcbbc6d6fef7d3d4a1c53438faad065927cc3bb18d5c6dcfc430aac527"; // replace with env var if needed
  const wallet = new ethers.Wallet(privateKey, provider);
  const stableCoinContract = new ethers.Contract(
    "0x8a26E58eC9505A950b69B0a8bD9445CBe299E72F",
    ABI,
    wallet
  );
  const allowance = await stableCoinContract.allowance(
    "0x4aAc55CcF940Cc3Bbbbc82f0a8537002583a42A8",
    contractAddress
  );
  const balance = await stableCoinContract.balanceOf(
    "0x4aAc55CcF940Cc3Bbbbc82f0a8537002583a42A8"
  );
  console.log("allowance", allowance);
  console.log("balance", balance);
  const _approveTransaction = await stableCoinContract.approve(
    contractAddress,
    ethers.MaxUint256,
    {
      gasPrice: ethers.parseUnits("30", "gwei"),
    }
  );
  const done = await _approveTransaction.wait();
  console.log("_approveTransaction", _approveTransaction);
  console.log("done", done);

  //   const _settlementTransaction = await stableCoinContract.settleInvoice(
  //     "105432470381086552333324246687108290450771910832063182109989691588609563338955",
  //     1,
  //     "0x4aAc55CcF940Cc3Bbbbc82f0a8537002583a42A8",
  //     {
  //       gasPrice: ethers.parseUnits("30", "gwei"),
  //     }
  //   );
})();

/// dueAmount = 120, tenure = 50, price = 100
/// ((((6000000 - 5000000)*10000)/5000000)*(360/1))
/// (((3.5 - 2.5)/2.5)*(360/0.01))*100
