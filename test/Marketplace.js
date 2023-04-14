const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice1 } = require("./data");

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
    ).deploy("USD Dollar", "USDC", buyer.address, 10000);

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
    await invoiceContract.createInvoice(user1.address, 1, invoice1);
    const amountToBuy = ethers.utils.parseEther("5000");

    await invoiceContract
      .connect(user1)
      .approve(
        marketplaceContract.address,
        1,
        1,
        ethers.utils.parseEther("10000")
      );

    const stableCoinAmount = await invoiceContract.calculateAdvanceAmount(
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
});
