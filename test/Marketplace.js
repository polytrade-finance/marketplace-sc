const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice } = require("./data");

describe("Marketplace", function () {
  let invoiceContract;
  let stableCoinContract;
  let marketplaceContract;
  let user1;
  let buyer;
  let treasuryWallet;
  let feeWallet;

  beforeEach(async () => {
    [, user1, buyer, treasuryWallet, feeWallet] = await ethers.getSigners();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();

    stableCoinContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", buyer.address, 200000);

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(
      invoiceContract.address,
      stableCoinContract.address,
      treasuryWallet.address,
      feeWallet.address
    );
  });

  it("it should revert on passing invalid invoice collection Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        ethers.constants.AddressZero,
        stableCoinContract.address,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.revertedWith("Marketplace: Invalid invoice collection address");
  });

  it("it should revert on passing invalid stable coin address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        ethers.constants.AddressZero,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.revertedWith("Marketplace: Invalid stable coin address");
  });

  it("it should revert on passing invalid treasury wallet Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        stableCoinContract.address,
        ethers.constants.AddressZero,
        feeWallet.address
      )
    ).to.revertedWith("Marketplace: Invalid treasury wallet address");
  });

  it("it should revert on passing invalid fee wallet Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        stableCoinContract.address,
        treasuryWallet.address,
        ethers.constants.AddressZero
      )
    ).to.revertedWith("Marketplace: Invalid fee wallet address");
  });

  it("it should return the invoice contract address while calling getInvoiceCollection()", async function () {
    expect(await marketplaceContract.getInvoiceCollection()).to.eq(
      invoiceContract.address
    );
  });

  it("it should return the stable coin contract address while calling getStableCoin()", async function () {
    expect(await marketplaceContract.getStableCoin()).to.eq(
      stableCoinContract.address
    );
  });

  it("it should return the treasury wallet address while calling getTreasuryWallet()", async function () {
    expect(await marketplaceContract.getTreasuryWallet()).to.eq(
      treasuryWallet.address
    );
  });

  it("it should return the fee wallet address while calling getFeeWallet()", async function () {
    expect(await marketplaceContract.getFeeWallet()).to.eq(feeWallet.address);
  });

  it("Creating invoice and selling it to buyer through Marketplace", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice.assetPrice,
      invoice.rewardApr,
      invoice.dueDate
    );

    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(user1.address, 1))
      .not.to.be.reverted;

    expect(await stableCoinContract.balanceOf(treasuryWallet.address)).to.eq(
      invoice.assetPrice
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
  });

  it("Creating multiple invoices and selling it to buyer through Marketplace", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice.assetPrice,
      invoice.rewardApr,
      invoice.dueDate
    );

    await invoiceContract.createInvoice(
      user1.address,
      2,
      invoice.assetPrice,
      invoice.rewardApr,
      invoice.dueDate
    );

    // user1 approves the amount he wants to sell
    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 2, 1, 1);

    const totalStableCoinAmount = invoice.assetPrice.add(invoice.assetPrice);

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, totalStableCoinAmount);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .batchBuy([user1.address, user1.address], [1, 2])
    ).not.to.be.reverted;

    expect(await stableCoinContract.balanceOf(treasuryWallet.address)).to.eq(
      totalStableCoinAmount
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
    expect(await invoiceContract.subBalanceOf(buyer.address, 2, 1)).to.eq(1);
  });

  it("Revert when no array parity in batchBuy", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice.assetPrice,
      invoice.rewardApr,
      invoice.dueDate
    );

    // user1 approves the amount he wants to sell
    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    // owners array length is 1 and the rest is two
    await expect(
      marketplaceContract.connect(buyer).batchBuy([user1.address], [1, 2])
    ).to.be.revertedWith("Marketplace: No array parity");
  });
});
