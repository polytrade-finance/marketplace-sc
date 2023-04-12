const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice1 } = require("./data");

describe("Invoice", function () {
  let invoiceContract;
  let deployer;
  beforeEach(async () => {
    [deployer] = await ethers.getSigners();

    const InvoiceFatory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFatory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();
  });

  it("Create Invoice successfully", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        "blablaURI",
        invoice1
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    expect(await invoiceContract.mainBalanceOf(deployer.address, 1)).to.eq(
      ethers.utils.parseEther("10000")
    );
  });

  it("Revert on Creating minted invoice", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        "blablaURI",
        invoice1
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    await expect(
      invoiceContract.createInvoice(deployer.address, 1, "blablaURI", invoice1)
    ).to.revertedWith("Invoice: Already minted");
  });
});
