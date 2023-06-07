const { expect } = require("chai");
const { ethers } = require("hardhat");
const { asset, MarketplaceAccess, DAY, YEAR } = require("./data");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");

describe("Marketplace", function () {
  let assetContract;
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

    const AssetFactory = await ethers.getContractFactory("Asset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await assetContract.deployed();

    stableTokenContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", 18, buyer.address, 200000);

    await stableTokenContract.decimals();

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(
      assetContract.address,
      stableTokenContract.address,
      treasuryWallet.address,
      feeWallet.address
    );
  });

  it("Should revert on passing invalid asset collection Address", async function () {
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

  it("Should revert on passing non-compatible asset collection Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        stableTokenContract.address, // non compatible to asset contract
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
        assetContract.address,
        ethers.constants.AddressZero,
        treasuryWallet.address,
        feeWallet.address
      )
    ).to.revertedWith("Invalid address");
  });

  it("Should revert on on relisting and asset without ownership", async function () {
    await expect(
      marketplaceContract.connect(user1).relist(1, asset.assetPrice)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should revert on passing invalid treasury wallet Address", async function () {
    await expect(
      (
        await ethers.getContractFactory("Marketplace")
      ).deploy(
        assetContract.address,
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
        assetContract.address,
        stableTokenContract.address,
        treasuryWallet.address,
        ethers.constants.AddressZero
      )
    ).to.revertedWith("Invalid wallet address");
  });

  it("Should return the asset contract address while calling getAssetCollection()", async function () {
    expect(await marketplaceContract.getAssetCollection()).to.eq(
      assetContract.address
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

  it("Should revert to settle asset without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).settleAsset(1)
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

  it("Should revert to settle asset before due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await assetContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, user1.address, 1);

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(marketplaceContract.settleAsset(1)).to.be.revertedWith(
      "Due date not passed"
    );
  });

  it("Should revert to settle asset with invalid id", async function () {
    await expect(marketplaceContract.settleAsset(1)).to.be.revertedWith(
      "Invalid asset id"
    );
  });

  it("Should create asset and revert if wrong owner calls claim reward", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await marketplaceContract.connect(buyer).buy(1);

    await expect(
      marketplaceContract.connect(user1).claimReward(1)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should create asset and selling it to buyer through Marketplace", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      asset.assetPrice
    );

    expect(await assetContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
  });

  it("Should create asset and selling it to buyer then claim rewards(before due date)", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    const tenure = 10 * DAY;
    await time.increase(tenure);

    const expectedReward = Math.round(
      (tenure * asset.assetPrice * asset.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await assetContract.getAvailableReward(1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract.connect(buyer).claimReward(1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    await assetContract.getRemainingReward(1);

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
  });

  it("Should create asset and selling it to buyer then claim rewards(after due date)", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    const tenure = asset.dueDate - (await now());
    await time.increase(YEAR);

    const expectedReward = Math.round(
      (tenure * asset.assetPrice * asset.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await assetContract.getAvailableReward(1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract.connect(buyer).claimReward(1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    const remainingReward = await assetContract.getRemainingReward(1);

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
    expect(remainingReward).to.eq(0);
  });

  it("Should create an asset settle the asset after due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await assetContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        0,
        await now()
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, user1.address, 1);

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(buyer.address);

    expect(await marketplaceContract.settleAsset(1))
      .to.emit(assetContract, "AssetSettled")
      .withArgs(1);

    const afterSettle = await stableTokenContract.balanceOf(buyer.address);

    expect(afterSettle.sub(beforeSettle)).to.be.equal(asset.assetPrice);
  });

  it("Should get remaining zero reward after due date", async function () {
    expect(
      await assetContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, user1.address, 1);

    await time.increase(YEAR);

    const expectedReward = 0;

    const actualReward = await assetContract.getRemainingReward(1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should create asset and selling it for 2 times and apply buying fees", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await marketplaceContract.setBuyingFee(1000);
    await marketplaceContract.setInitialFee(2000);

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, 2 * asset.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.address, 2 * asset.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, 2 * asset.assetPrice);

    const before1stBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await expect(await marketplaceContract.connect(buyer).buy(1)).not.to.be
      .reverted;
    await marketplaceContract.connect(buyer).relist(1, asset.assetPrice);

    const after1stBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await assetContract
      .connect(buyer)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.address, 2 * asset.assetPrice);

    const before2ndBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await expect(await marketplaceContract.connect(user1).buy(1)).not.to.be
      .reverted;

    const after2ndBuy = await stableTokenContract.balanceOf(feeWallet.address);

    const expected1stFee = (asset.assetPrice * 2000) / 10000;
    const expected2ndFee = (asset.assetPrice * 1000) / 10000;

    expect(after1stBuy.sub(before1stBuy)).to.eq(expected1stFee);

    expect(after2ndBuy.sub(before2ndBuy)).to.eq(expected2ndFee);
  });

  it("Should create multiple assets and selling it to buyer through Marketplace", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await assetContract.createAsset(
      user1.address,
      2,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    // user1 approves the amount he wants to sell
    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 2, 1, 1);

    const totalStableTokenAmount = asset.assetPrice.add(asset.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, totalStableTokenAmount);

    await expect(await marketplaceContract.connect(buyer).batchBuy([1, 2])).not
      .to.be.reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      totalStableTokenAmount
    );

    expect(await assetContract.subBalanceOf(buyer.address, 1, 1)).to.eq(1);
    expect(await assetContract.subBalanceOf(buyer.address, 2, 1)).to.eq(1);
  });

  it("Should revert when asset is not relisted", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await assetContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    // user1 approves the amount he wants to sell
    await assetContract
      .connect(user1)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await marketplaceContract.connect(buyer).buy(1);

    await expect(marketplaceContract.connect(user1).buy(1)).to.be.revertedWith(
      "Asset is not listed"
    );
  });
});