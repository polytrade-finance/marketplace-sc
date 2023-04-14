const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice1 } = require("./data");

describe("Invoice", function () {
  let invoiceContract;
  let tokenContract;
  let marketplaceContract;
  let deployer;
  before(async () => {
    [deployer] = await ethers.getSigners();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();

    tokenContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", deployer.address, 10000);

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(invoiceContract.address, tokenContract.address);
  });

  it("Applying Before test", async function () {});
});
