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

  beforeEach(async () => {
    [, user1, buyer] = await ethers.getSigners();

    const FormulasFactory = await ethers.getContractFactory("Formulas");
    formulasContract = await FormulasFactory.deploy();

    await formulasContract.deployed();

    stableCoinContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", buyer.address, 200000);

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs",
      formulasContract.address,
      stableCoinContract.address
    );

    await invoiceContract.deployed();

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(invoiceContract.address, stableCoinContract.address);
  });

  it("Test Marketplace's Invoice collection Getter", async function () {
    expect(await marketplaceContract.getInvoiceCollection()).to.eq(
      invoiceContract.address
    );
  });

  it("Test Marketplace's Token Getter", async function () {
    expect(await marketplaceContract.getStableCoin()).to.eq(
      stableCoinContract.address
    );
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

    const stableCoinAmount = await invoiceContract.advanceAmountCalculation(
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

    const stableCoinAmount1 = await invoiceContract.advanceAmountCalculation(
      1,
      1,
      amountToBuy1
    );

    const stableCoinAmount2 = await invoiceContract.advanceAmountCalculation(
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

    const stableCoinAmount1 = await invoiceContract.advanceAmountCalculation(
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
