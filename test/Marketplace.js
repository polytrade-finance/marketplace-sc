const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice1, DECIMALS } = require("./data");
const { BigNumber } = require("ethers");

describe("Invoice", function () {
  let formulasContract;
  let invoiceContract;
  let stableCoinContract;
  let marketplaceContract;
  let user1;
  let buyer;
  let treasuryWallet;
  let feeWallet;
  let newTreasuryWallet;
  let newFeeWallet;

  beforeEach(async () => {
    [
      ,
      user1,
      buyer,
      treasuryWallet,
      feeWallet,
      newTreasuryWallet,
      newFeeWallet,
    ] = await ethers.getSigners();

    const FormulasFactory = await ethers.getContractFactory("Formulas");
    formulasContract = await FormulasFactory.deploy();

    await formulasContract.deployed();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs",
      formulasContract.address
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

  it("it should revert on passing Zero Address rather than invalid invoice collection Address", async function () {
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

  it("Should revert on passing non-compatible invoice collection Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        stableCoinContract.address, // non compatible to invoice contract
        stableCoinContract.address,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.revertedWith("Marketplace: Non compatible invoice collection");
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

  it("Should set a new treasury wallet address while calling setTreasuryWallet()", async function () {
    await expect(
      await marketplaceContract.setTreasuryWallet(newTreasuryWallet.address)
    ).not.to.be.reverted;

    expect(await marketplaceContract.getTreasuryWallet()).to.eq(
      newTreasuryWallet.address
    );
  });

  it("Should revert when setting a new treasury wallet by invalid sender address while calling setTreasuryWallet()", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .setTreasuryWallet(newTreasuryWallet.address)
    ).to.be.reverted;
  });

  it("Should set a new fee wallet address while calling setFeeWallet()", async function () {
    await expect(await marketplaceContract.setFeeWallet(newFeeWallet.address))
      .not.to.be.reverted;

    expect(await marketplaceContract.getFeeWallet()).to.eq(
      newFeeWallet.address
    );
  });

  it("Should revert when setting a new fee wallet by invalid sender address while calling setFeeWallet()", async function () {
    await expect(
      marketplaceContract.connect(user1).setFeeWallet(newFeeWallet.address)
    ).to.be.reverted;
  });

  it("Creating invoice and selling it to buyer through Marketplace", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );
    const amountToBuy = ethers.utils.parseUnits("5000", DECIMALS.SIX);

    await invoiceContract
      .connect(user1)
      .approve(
        marketplaceContract.address,
        1,
        1,
        ethers.utils.parseUnits("10000", DECIMALS.SIX)
      );

    const stableCoinAmount = await invoiceContract.calculateAdvanceAmount(
      1,
      1,
      amountToBuy
    );

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, stableCoinAmount);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(user1.address, 1, 1, amountToBuy)
    ).not.to.be.reverted;

    expect(await stableCoinContract.balanceOf(user1.address)).to.eq(
      stableCoinAmount
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(
      amountToBuy
    );
  });

  it("Creating multiple invoices and selling it to buyer through Marketplace", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    await invoiceContract.createInvoice(
      user1.address,
      2,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    const amountToBuy1 = ethers.utils.parseUnits("5000", DECIMALS.SIX);
    const amountToBuy2 = ethers.utils.parseUnits("6000", DECIMALS.SIX);

    // user1 approves the amount he wants to sell
    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, amountToBuy1);

    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 2, 1, amountToBuy2);

    const stableCoinAmount1 = await invoiceContract.calculateAdvanceAmount(
      1,
      1,
      amountToBuy1
    );

    const stableCoinAmount2 = await invoiceContract.calculateAdvanceAmount(
      2,
      1,
      amountToBuy2
    );

    const totalStableCoinAmount = BigNumber.from(stableCoinAmount1).add(
      BigNumber.from(stableCoinAmount2)
    );

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, totalStableCoinAmount);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .batchBuy(
          [user1.address, user1.address],
          [1, 2],
          [1, 1],
          [amountToBuy1, amountToBuy2]
        )
    ).not.to.be.reverted;

    expect(await stableCoinContract.balanceOf(user1.address)).to.eq(
      totalStableCoinAmount
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(
      amountToBuy1
    );
    expect(await invoiceContract.subBalanceOf(buyer.address, 2, 1)).to.eq(
      amountToBuy2
    );
  });

  it("Revert when no array parity in batchBuy", async function () {
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    const amountToBuy1 = ethers.utils.parseUnits("5000", DECIMALS.SIX);

    // user1 approves the amount he wants to sell
    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, amountToBuy1);

    const stableCoinAmount1 = await invoiceContract.calculateAdvanceAmount(
      1,
      1,
      amountToBuy1
    );

    await stableCoinContract
      .connect(buyer)
      .approve(marketplaceContract.address, stableCoinAmount1);

    // owners array length is 1 and the rest is two
    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy([user1.address], [1, 2], [1, 1], [amountToBuy1, 0])
    ).to.be.revertedWith("Marketplace: No array parity");
  });
});
