const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Invoice", function () {
  let invoice;

  beforeEach(async () => {
    const InvoiceFatory = await ethers.getContractFactory("Invoice");
    invoice = await InvoiceFatory.deploy("Polytrade Invoice Collection", "PIC");
    await invoice.deployed();
  });

  it("should do something", async function () {
    // TODO: Write your test case here
  });
});
