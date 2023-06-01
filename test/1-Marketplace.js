const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice, MarketplaceAccess, DAY, YEAR } = require("./data");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");

describe("Marketplace", function () {
  let invoiceContract;
  let stableTokenContract;
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

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();

    stableTokenContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", buyer.address, 200000);

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(
      invoiceContract.address,
      stableTokenContract.address,
      treasuryWallet.address,
      feeWallet.address
    );
  });

  it("Should revert on passing invalid invoice collection Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        ethers.constants.AddressZero,
        stableTokenContract.address,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "UnsupportedInterface"
    );
  });

  it("Should revert on passing non-compatible invoice collection Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        stableTokenContract.address, // non compatible to invoice contract
        stableTokenContract.address,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "UnsupportedInterface"
    );
  });

  it("Should revert on passing invalid stable token address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        ethers.constants.AddressZero,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.revertedWith("Invalid address");
  });

  it("Should revert on passing invalid treasury wallet Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        stableTokenContract.address,
        ethers.constants.AddressZero,
        feeWallet.address
      )
    ).to.revertedWith("Invalid wallet address");
  });

  it("Should revert on passing invalid fee wallet Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        invoiceContract.address,
        stableTokenContract.address,
        treasuryWallet.address,
        ethers.constants.AddressZero
      )
    ).to.revertedWith("Marketplace: Invalid fee wallet address");
  });

  it("Should return the invoice contract address while calling getInvoiceCollection()", async function () {
    expect(await marketplaceContract.getInvoiceCollection()).to.eq(
      invoiceContract.address
    );
  });

  it("Should return the stable token contract address while calling getStableToken()", async function () {
    expect(await marketplaceContract.getStableToken()).to.eq(
      stableTokenContract.address
    );
  });

  it("Should return the treasury wallet address while calling getTreasuryWallet()", async function () {
    expect(await marketplaceContract.getTreasuryWallet()).to.eq(
      treasuryWallet.address
    );
  });

  it("Should return the fee wallet address while calling getFeeWallet()", async function () {
    expect(await marketplaceContract.getFeeWallet()).to.eq(feeWallet.address);
  });

  it("Should set a new initial fee (10.00%) percentage for first buy", async function () {
    await expect(await marketplaceContract.setInitialFee(1000)).not.to.be
      .reverted;

    expect(await marketplaceContract.initialFee()).to.eq(1000);
  });

  it("Should set a new buying fee (10.00%) percentage for all buys", async function () {
    await expect(await marketplaceContract.setBuyingFee(1000)).not.to.be
      .reverted;

    expect(await marketplaceContract.buyingFee()).to.eq(1000);
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

  it("Should revert to set initial fee without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).setInitialFee(1000)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should revert to settle invoice without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).settleInvoice(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should revert to set buying fee without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).setBuyingFee(1000)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
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

  it("Should revert to claim reward if asset does not exist or not bought yet", async function () {
    await expect(
      marketplaceContract.connect(user1).claimReward(1)
    ).to.be.revertedWith("Asset not bought yet");
  });

  it("Should create invoice and revert if wrong owner calls claim reward", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
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

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await marketplaceContract.connect(buyer).buy(1);

    await expect(
      marketplaceContract.connect(user1).claimReward(1)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should create invoice and selling it to buyer through Marketplace", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
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

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      invoice.assetPrice
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
  });

  it("Should create invoice and selling it to buyer then claim rewards(before due date)", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
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

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    const tenure = 10 * DAY;
    await time.increase(tenure);

    const expectedReward = Math.round(
      (tenure * invoice.assetPrice * invoice.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await invoiceContract.getAvailableReward(1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract.connect(buyer).claimReward(1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    await invoiceContract.getRemainingReward(1);

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
  });

  it("Should create invoice and selling it to buyer then claim rewards(after due date)", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

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

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    const tenure = invoice.dueDate - (await now());
    await time.increase(YEAR);

    const expectedReward = Math.round(
      (tenure * invoice.assetPrice * invoice.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await invoiceContract.getAvailableReward(1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract.connect(buyer).claimReward(1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    const remainingReward = await invoiceContract.getRemainingReward(1);

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
    expect(remainingReward).to.eq(0);
  });

  it("Should create an invoice settle the invoice after due date", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await invoiceContract.createInvoice(
        user1.address,
        1,
        invoice.assetPrice,
        0,
        await now()
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(user1.address, user1.address, 1);

    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(buyer.address);

    expect(await marketplaceContract.settleInvoice(1))
      .to.emit(invoiceContract, "InvoiceSettled")
      .withArgs(1);

    const afterSettle = await stableTokenContract.balanceOf(buyer.address);

    expect(afterSettle.sub(beforeSettle)).to.be.equal(invoice.assetPrice);
  });

  it("Should create an invoice and settle it after due date", async function () {
    expect(
      await invoiceContract.createInvoice(
        user1.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(user1.address, user1.address, 1);

    await time.increase(YEAR);

    const expectedReward = 0;

    const actualReward = await invoiceContract.getRemainingReward(1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should create invoice and selling it for 2 times and apply buying fees", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await invoiceContract.createInvoice(
      user1.address,
      1,
      invoice.assetPrice,
      invoice.rewardApr,
      invoice.dueDate
    );

    await marketplaceContract.setBuyingFee(1000);
    await marketplaceContract.setInitialFee(2000);

    await invoiceContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, 2 * invoice.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.address, 2 * invoice.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.address, invoice.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, 2 * invoice.assetPrice);

    const before1stBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;
    await marketplaceContract.connect(buyer).reList(1, invoice.assetPrice);

    const after1stBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await invoiceContract
      .connect(buyer)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.address, 2 * invoice.assetPrice);

    const before2ndBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await expect(await marketplaceContract.connect(user1).buy(1)).not.to.be
      .reverted;

    const after2ndBuy = await stableTokenContract.balanceOf(feeWallet.address);

    const expected1stFee = (invoice.assetPrice * 2000) / 10000;
    const expected2ndFee = (invoice.assetPrice * 1000) / 10000;

    expect(after1stBuy.sub(before1stBuy)).to.eq(expected1stFee);

    expect(after2ndBuy.sub(before2ndBuy)).to.eq(expected2ndFee);
  });

  it("Should create multiple invoices and selling it to buyer through Marketplace", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
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

    const totalStableTokenAmount = invoice.assetPrice.add(invoice.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, totalStableTokenAmount);

    await expect(await marketplaceContract.connect(buyer).batchBuy([1, 2])).not
      .to.be.reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      totalStableTokenAmount
    );

    expect(await invoiceContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
    expect(await invoiceContract.subBalanceOf(buyer.address, 2, 1)).to.eq(1);
  });

  it("Should revert when asset is not relisted", async function () {
    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

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

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, invoice.assetPrice);

    await marketplaceContract.connect(buyer).buy(1);

    await expect(marketplaceContract.connect(user1).buy(1)).to.be.revertedWith(
      "Invoice is not listed"
    );
  });
});
