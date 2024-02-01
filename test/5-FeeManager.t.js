const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Fee Manager", function () {
  let buyer;
  let feeWallet;
  let feeManager;
  let newFeeWallet;

  beforeEach(async () => {
    [, , buyer, , feeWallet, newFeeWallet] = await ethers.getSigners();

    const FeeManagerFactory = await ethers.getContractFactory("FeeManager");
    feeManager = await FeeManagerFactory.deploy(
      0,
      0,
      await feeWallet.getAddress()
    );

    await feeManager.waitForDeployment();
  });

  it("Should revert to set default fee without admin access", async function () {
    await expect(
      feeManager.connect(buyer).setDefaultFees(1000, 2000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to set initial fee without admin access", async function () {
    await expect(
      feeManager.connect(buyer).setInitialFee(1, 1, 1000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to set buying fee without admin access", async function () {
    await expect(
      feeManager.connect(buyer).setBuyingFee(1, 1, 1000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to batch set initial fee without admin access", async function () {
    await expect(
      feeManager.connect(buyer).batchSetInitialFee([1], [1], [1000])
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to batch set initial fee without array parity", async function () {
    await expect(feeManager.batchSetInitialFee([1, 1], [1], [1000])).to.be
      .reverted;

    await expect(feeManager.batchSetInitialFee([1, 1], [1, 1], [1000])).to.be
      .reverted;
  });

  it("Should revert to batch set buying fee without admin access", async function () {
    await expect(
      feeManager.connect(buyer).batchSetBuyingFee([1], [1], [1000])
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to batch set buying fee without array parity", async function () {
    await expect(feeManager.batchSetBuyingFee([1, 1], [1], [1000])).to.be
      .reverted;

    await expect(feeManager.batchSetBuyingFee([1, 1], [1, 1], [1000])).to.be
      .reverted;
  });

  it("Should revert to set new fee wallet without admin acces", async function () {
    await expect(
      feeManager.connect(buyer).setFeeWallet(newFeeWallet.getAddress())
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to set new fee wallet with zero address", async function () {
    await expect(feeManager.setFeeWallet(ethers.ZeroAddress)).to.be.reverted;
  });

  it("Should revert to set default fees more than 100%", async function () {
    await expect(feeManager.setDefaultFees(10001, 2000)).to.be.reverted;
    await expect(feeManager.setDefaultFees(10000, 20000)).to.be.reverted;
  });

  it("Should revert to set initial and buying fees more than 100%", async function () {
    await expect(feeManager.setInitialFee(1, 1, 10001)).to.be.reverted;
    await expect(feeManager.setBuyingFee(1, 1, 20000)).to.be.reverted;
  });

  it("Should set default fees and get the values", async function () {
    await feeManager.setDefaultFees(1000, 2000);

    expect(await feeManager.getDefaultInitialFee()).to.be.eq(1000);
    expect(await feeManager.getDefaultBuyingFee()).to.be.eq(2000);
  });

  it("Should set initial fee and get the value", async function () {
    await feeManager.setInitialFee(1, 1, 1000);

    expect(await feeManager.getInitialFee(1, 1)).to.be.eq(1000);
  });

  it("Should set buying fee and get the value", async function () {
    await feeManager.setBuyingFee(1, 1, 2000);

    expect(await feeManager.getBuyingFee(1, 1)).to.be.eq(2000);
  });

  it("Should batch set initial fees and get the values", async function () {
    await feeManager.batchSetInitialFee([1, 2], [1, 1], [1000, 2000]);

    expect(await feeManager.getInitialFee(1, 1)).to.be.eq(1000);
    expect(await feeManager.getInitialFee(2, 1)).to.be.eq(2000);
  });

  it("Should batch set buying fees and get the values", async function () {
    await feeManager.batchSetBuyingFee([1, 2], [1, 1], [1000, 2000]);

    expect(await feeManager.getBuyingFee(1, 1)).to.be.eq(1000);
    expect(await feeManager.getBuyingFee(2, 1)).to.be.eq(2000);
  });

  it("Should set new fee wallet and get the address", async function () {
    await feeManager.setFeeWallet(newFeeWallet.getAddress());

    expect(await feeManager.getFeeWallet()).to.be.eq(
      await newFeeWallet.getAddress()
    );
  });

  it("Should return default fee if not set", async function () {
    expect(await feeManager.getInitialFee(1, 1)).to.be.eq(0);
    expect(await feeManager.getBuyingFee(1, 1)).to.be.eq(0);

    await feeManager.setInitialFee(1, 1, 1000);
    await feeManager.setBuyingFee(1, 1, 2000);

    expect(await feeManager.getInitialFee(1, 1)).to.be.eq(1000);
    expect(await feeManager.getBuyingFee(1, 1)).to.be.eq(2000);
  });
});
