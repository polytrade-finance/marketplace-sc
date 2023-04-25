// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

const {
  BUYER_PUBLIC_KEY,
  TOKEN_NAME,
  TOKEN_SYMBOL,
  INVOICE_COLLECTION_SYMBOL,
  INVOICE_COLLECTION_BASE_URI,
} = process.env;

async function main() {
  // We get the contract to deploy

  const FormulasFactory = await hre.ethers.getContractFactory("Formulas");
  const formulasContract = await FormulasFactory.deploy();
  await formulasContract.deployed();
  console.log("formulasContract deployed to:", formulasContract.address);

  const InvoiceFactory = await hre.ethers.getContractFactory("Invoice");
  const invoiceContract = await InvoiceFactory.deploy(
    "Polytrade Invoice Collection",
    INVOICE_COLLECTION_SYMBOL,
    INVOICE_COLLECTION_BASE_URI,
    formulasContract.address
  );
  await invoiceContract.deployed();
  console.log("invoiceContract deployed to:", invoiceContract.address);

  const StableCoinFactory = await hre.ethers.getContractFactory("Token");
  const stableCoinContract = await StableCoinFactory.deploy(
    TOKEN_NAME,
    TOKEN_SYMBOL,
    BUYER_PUBLIC_KEY,
    200000
  );
  await stableCoinContract.deployed();
  console.log("stableCoinContract deployed to:", stableCoinContract.address);

  const MarketplaceFactory = await hre.ethers.getContractFactory("Marketplace");
  const marketplaceContract = await MarketplaceFactory.deploy(
    invoiceContract.address,
    stableCoinContract.address
  );
  await marketplaceContract.deployed();
  console.log("marketplaceContract deployed to:", marketplaceContract.address);

  await hre.run("verify:verify", {
    address: formulasContract.address,
    constructorArguments: [],
  });

  await hre.run("verify:verify", {
    address: formulasContract.address,
    constructorArguments: [
      "Polytrade Invoice Collection",
      INVOICE_COLLECTION_SYMBOL,
      INVOICE_COLLECTION_BASE_URI,
      formulasContract.address,
    ],
  });

  await hre.run("verify:verify", {
    address: formulasContract.address,
    constructorArguments: [TOKEN_NAME, TOKEN_SYMBOL, BUYER_PUBLIC_KEY, 200000],
  });

  await hre.run("verify:verify", {
    address: formulasContract.address,
    constructorArguments: [invoiceContract.address, stableCoinContract.address],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().then(() => {
  throw new Error("Succeeded");
});

// npx hardhat run --network mumbai scripts/deploy.js
