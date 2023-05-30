const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice, YEAR } = require("./data");
const { now } = require("./helpers");

describe("Invoice", function () {
  let invoiceContract;
  let deployer;
  let user1;
  let currentTime;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    currentTime = await now();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();
  });

  it("Should create invoice successfully", async function () {
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

  it("Should revert on creating minted invoice", async function () {
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

  it("Should revert on creating invoice by invalid caller", async function () {
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

  it("Should to set new base uri", async function () {
    await expect(invoiceContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Should revert to set new base uri by invalid caller", async function () {
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
  it("Should revert Batch create invoices on wrong array parity", async function () {
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

  it("Should revert on batch creating invoices by invalid caller", async function () {
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
  it("Should create an invoice and get remaining rewards", async function () {
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

    const tenure = invoice.dueDate - currentTime;
    const reward =
      ((invoice.rewardApr / 10000) * tenure * invoice.assetPrice) / YEAR;
    const expectedReward = Math.round(reward);
    const actualReward = await invoiceContract.getRemainingReward(1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);
  });

  it("Should return zero rewards for minted invoice with zero price", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        0,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    const expectedReward = 0;
    const actualReward = await invoiceContract.getRemainingReward(1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should return zero rewards for not minted invoice", async function () {
    const expectedReward = 0;
    const actualReward = await invoiceContract.getRemainingReward(2);

    expect(actualReward).to.be.equal(expectedReward);
  });
});
