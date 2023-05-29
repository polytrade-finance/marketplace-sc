const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice } = require("./data");

describe("Invoice", function () {
  let invoiceContract;
  let deployer;
  let user1;
  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
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
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    expect(await invoiceContract.mainBalanceOf(deployer.address, 1)).to.eq(1);

    expect(await invoiceContract.tokenURI(1)).to.eq(`https://ipfs.io/ipfs${1}`);
  });

  it("Revert on Creating minted invoice", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    await expect(
      invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    ).to.revertedWith("Invoice: Already minted");
  });

  it("Revert on Creating invoice by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .createInvoice(
          deployer.address,
          1,
          invoice.assetPrice,
          invoice.rewardApr,
          invoice.dueDate
        )
    ).to.be.reverted;
  });

  it("Set new base uri", async function () {
    await expect(invoiceContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Revert Set new base uri by invalid caller", async function () {
    await expect(
      invoiceContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });

  it("Batch create invoices", async function () {
    await invoiceContract.batchCreateInvoice(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
      [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
      [invoice.dueDate, invoice.dueDate, invoice.dueDate]
    );

    expect(await invoiceContract.mainBalanceOf(user1.address, 1)).to.eq(1);

    expect(await invoiceContract.mainBalanceOf(user1.address, 2)).to.eq(1);

    expect(await invoiceContract.mainBalanceOf(user1.address, 3)).to.eq(1);
  });
  it("Revert Batch create invoices on wrong array parity", async function () {
    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address, user1.address],
        [1, 2],
        [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
        [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
        [
          invoice.dueDate,
          invoice.dueDate,
          // invoice.dueDate,
        ]
      )
    ).to.be.revertedWith("Invoice: No array parity");

    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address],
        [1, 2, 3],
        [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
        [
          invoice.rewardApr,
          invoice.rewardApr,
          // invoice.rewardApr,
        ],
        [invoice.dueDate, invoice.dueDate, invoice.dueDate]
      )
    ).to.be.revertedWith("Invoice: No array parity");
  });

  it("Revert on Batch Creating invoices by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .batchCreateInvoice(
          [user1.address, user1.address, user1.address],
          [1, 2, 3],
          [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
          [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
          [invoice.dueDate, invoice.dueDate, invoice.dueDate]
        )
    ).to.be.reverted;
  });
});
