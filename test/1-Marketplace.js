const { expect } = require("chai");
const { ethers } = require("hardhat");
const { asset, MarketplaceAccess, DAY, YEAR } = require("./data");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");

describe("Marketplace", function () {
  let assetContract;
  let asset721Contract;
  let asset1155Contract;
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
      "PAC",
      "2.1",
      "https://ipfs.io/ipfs"
    );

    await assetContract.deployed();

    const Asset721Factory = await ethers.getContractFactory("ERC721Token");
    asset721Contract = await Asset721Factory.deploy();

    await asset721Contract.deployed();

    const Asset1155Factory = await ethers.getContractFactory("ERC1155Token");
    asset1155Contract = await Asset1155Factory.deploy();

    await assetContract.deployed();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
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

  it("Should create asset successfully", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, 1);

    expect(await assetContract.subIdBalanceOf(user1.address, 1)).to.eq(1);

    expect(await assetContract.tokenURI(1)).to.eq(`https://ipfs.io/ipfs${1}`);
  });

  it("Should revert to set list erc721 asset without admin role", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .list721Asset(
          asset721Contract.address,
          user1.address,
          0,
          asset.assetPrice,
          asset.rewardApr,
          asset.dueDate
        )
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should revert to set list erc1155 asset without admin role", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .list1155Asset(
          asset1155Contract.address,
          user1.address,
          0,
          asset.assetPrice,
          asset.rewardApr,
          asset.dueDate
        )
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should list erc721 asset successfully", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset721Contract.safeMint(user1.address);

    expect(
      await marketplaceContract.list721Asset(
        asset721Contract.address,
        user1.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetListed")
      .withArgs(asset721Contract, user1.address, 1);
  });

  it("Should revert to list asset for second time", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset721Contract.safeMint(user1.address);

    expect(
      await marketplaceContract.list721Asset(
        asset721Contract.address,
        user1.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetListed")
      .withArgs(asset721Contract, user1.address, 1);

    await expect(
      marketplaceContract.list721Asset(
        asset721Contract.address,
        user1.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("Asset already listed");
  });

  it("Should revert to list erc721 asset if owner is wrong", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset721Contract.safeMint(user1.address);

    await expect(
      marketplaceContract.list721Asset(
        asset721Contract.address,
        buyer.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("owner does not own the asset");
  });

  it("Should revert on passing invalid erc721 asset collection Address", async function () {
    await expect(
      marketplaceContract.list721Asset(
        assetContract.address,
        buyer.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "UnsupportedInterface"
    );
  });

  it("Should list erc1155 asset successfully", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset1155Contract.mint(user1.address, 1, 1);

    expect(
      await marketplaceContract.list1155Asset(
        asset1155Contract.address,
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetListed")
      .withArgs(asset1155Contract, user1.address, 1);
  });

  it("Should revert to list erc1155 asset if owner is wrong", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset1155Contract.mint(user1.address, 1, 1);

    await expect(
      marketplaceContract.list1155Asset(
        asset1155Contract.address,
        buyer.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("owner does not own the asset");
  });

  it("Should revert on passing invalid erc1155 asset collection Address", async function () {
    await expect(
      marketplaceContract.list1155Asset(
        asset721Contract.address,
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.be.revertedWithCustomError(
      marketplaceContract,
      "UnsupportedInterface"
    );
  });

  it("Should burn asset successfully", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, 1);

    expect(await assetContract.subIdBalanceOf(user1.address, 1)).to.eq(1);

    expect(await marketplaceContract.burnAsset(user1.address, 1))
      .to.emit(assetContract, "AssetBurnt")
      .withArgs(user1.address, 1);

    expect(await assetContract.subIdBalanceOf(user1.address, 1)).to.eq(0);
  });

  it("Should revert to create asset with invalid owner address", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await expect(
      marketplaceContract.createAsset(
        ethers.constants.AddressZero,
        1,
        0,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("DLT: mint to the zero address");
  });

  it("Batch create assets", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await marketplaceContract.batchCreateAsset(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [asset.assetPrice, asset.assetPrice, asset.assetPrice],
      [asset.rewardApr, asset.rewardApr, asset.rewardApr],
      [asset.dueDate, asset.dueDate, asset.dueDate]
    );

    expect(await assetContract.subIdBalanceOf(user1.address, 1)).to.eq(1);

    expect(await assetContract.subIdBalanceOf(user1.address, 2)).to.eq(1);

    expect(await assetContract.subIdBalanceOf(user1.address, 3)).to.eq(1);
  });

  it("Should revert Batch create assets on wrong array parity", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await expect(
      marketplaceContract.batchCreateAsset(
        [user1.address, user1.address, user1.address],
        [1, 2],
        [asset.assetPrice, asset.assetPrice, asset.assetPrice],
        [asset.rewardApr, asset.rewardApr, asset.rewardApr],
        [
          asset.dueDate,
          asset.dueDate,
          // asset.dueDate,
        ]
      )
    ).to.be.revertedWith("No array parity");

    await expect(
      marketplaceContract.batchCreateAsset(
        [user1.address, user1.address],
        [1, 2, 3],
        [asset.assetPrice, asset.assetPrice, asset.assetPrice],
        [
          asset.rewardApr,
          asset.rewardApr,
          // asset.rewardApr,
        ],
        [asset.dueDate, asset.dueDate, asset.dueDate]
      )
    ).to.be.revertedWith("No array parity");
  });

  it("Should revert on batch creating assets by invalid caller", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await expect(
      marketplaceContract
        .connect(user1)
        .batchCreateAsset(
          [user1.address, user1.address, user1.address],
          [1, 2, 3],
          [asset.assetPrice, asset.assetPrice, asset.assetPrice],
          [asset.rewardApr, asset.rewardApr, asset.rewardApr],
          [asset.dueDate, asset.dueDate, asset.dueDate]
        )
    ).to.be.reverted;
  });

  it("Should return zero rewards for minted asset with zero price", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        0,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(marketplaceContract, "AssetListed")
      .withArgs(assetContract.address, user1.address, 1);

    const expectedReward = 0;
    const actualReward = await marketplaceContract.getRemainingReward(
      assetContract.address,
      1
    );

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should revert on creating minted asset", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(marketplaceContract, "AssetListed")
      .withArgs(assetContract.address, user1.address, 1);

    await expect(
      marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("Asset already created");
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
      marketplaceContract
        .connect(user1)
        .relist(assetContract.address, 1, asset.assetPrice)
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

  it("Should return the asset info struct", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(user1.address, 1);

    const info = await marketplaceContract.getAssetInfo(
      assetContract.address,
      1
    );

    expect(info.owner).to.eq(user1.address);
    expect(info.price).to.eq(asset.assetPrice);
    expect(info.rewardApr).to.eq(asset.rewardApr);
    expect(info.dueDate).to.eq(asset.dueDate);
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

    expect(await marketplaceContract.getInitialFee()).to.eq(1000);
  });

  it("Should set a new buying fee (10.00%) percentage for all buys", async function () {
    await expect(await marketplaceContract.setBuyingFee(1000)).not.to.be
      .reverted;

    expect(await marketplaceContract.getBuyingFee()).to.eq(1000);
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

  it("Should revert to create asset without admin role", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .createAsset(
          user1.address,
          1,
          asset.assetPrice,
          asset.rewardApr,
          asset.dueDate
        )
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should revert to burn asset without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).burnAsset(user1.address, 1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${ethers.utils.hexZeroPad(
        ethers.utils.hexlify(0),
        32
      )}`
    );
  });

  it("Should revert to settle asset without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).settleAsset(assetContract.address, 1)
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
      marketplaceContract.connect(user1).claimReward(assetContract.address, 1)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should revert to settle asset before due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(marketplaceContract, "AssetListed")
      .withArgs(assetContract.address, user1.address, 1);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(
      marketplaceContract.settleAsset(assetContract.address, 1)
    ).to.be.revertedWith("Due date not passed");
  });

  it("Should revert to settle asset with invalid id", async function () {
    await expect(
      marketplaceContract.settleAsset(assetContract.address, 1)
    ).to.be.revertedWith("Invalid asset id");
  });

  it("Should create asset and revert if wrong owner calls claim reward", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await marketplaceContract.connect(buyer).buy(assetContract.address, 1);

    await expect(
      marketplaceContract.connect(user1).claimReward(assetContract.address, 1)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should create asset and selling it to buyer through Marketplace", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(
      await marketplaceContract.connect(buyer).buy(assetContract.address, 1)
    ).not.to.be.reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      asset.assetPrice
    );

    expect(
      await assetContract.subIdBalanceOf(marketplaceContract.address, 1)
    ).to.eq(1);
  });

  it("Should list erc721 asset and selling it to buyer through Marketplace", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset721Contract.safeMint(user1.address);

    expect(
      await marketplaceContract.list721Asset(
        asset721Contract.address,
        user1.address,
        0,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetListed")
      .withArgs(asset721Contract, user1.address, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await asset721Contract
      .connect(user1)
      .setApprovalForAll(marketplaceContract.address, true);

    await marketplaceContract.connect(buyer).buy(asset721Contract.address, 0);

    expect(await asset721Contract.ownerOf(0)).to.eq(
      marketplaceContract.address
    );
  });

  it("Should list erc1155 asset and selling it to buyer through Marketplace", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await asset1155Contract.mint(user1.address, 1, 1);

    expect(
      await marketplaceContract.list1155Asset(
        asset1155Contract.address,
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetListed")
      .withArgs(asset1155Contract, user1.address, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await asset1155Contract
      .connect(user1)
      .setApprovalForAll(marketplaceContract.address, true);

    await marketplaceContract.connect(buyer).buy(asset1155Contract.address, 1);

    expect(
      await asset1155Contract.balanceOf(marketplaceContract.address, 1)
    ).to.eq(1);
  });

  it("Should create asset and selling it to buyer then claim rewards(before due date)", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    expect(
      await marketplaceContract.getAvailableReward(assetContract.address, 1)
    ).to.eq(0);

    await marketplaceContract.connect(buyer).buy(assetContract.address, 1);

    const tenure = 10 * DAY;
    await time.increase(tenure);

    const expectedReward = Math.round(
      (tenure * asset.assetPrice * asset.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await marketplaceContract.getAvailableReward(
      assetContract.address,
      1
    );

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract
      .connect(buyer)
      .claimReward(assetContract.address, 1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    await marketplaceContract.getRemainingReward(assetContract.address, 1);

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
  });

  it("Should create asset and selling it to buyer then claim rewards(after due date)", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(
      await marketplaceContract.connect(buyer).buy(assetContract.address, 1)
    ).not.to.be.reverted;

    const tenure = asset.dueDate - (await now());
    await time.increase(YEAR);

    const expectedReward = Math.round(
      (tenure * asset.assetPrice * asset.rewardApr) / (10000 * YEAR)
    );
    const actualReward = await marketplaceContract.getAvailableReward(
      assetContract.address,
      1
    );

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    const beforeClaim = await stableTokenContract.balanceOf(buyer.address);
    await marketplaceContract
      .connect(buyer)
      .claimReward(assetContract.address, 1);
    const afterClaim = await stableTokenContract.balanceOf(buyer.address);

    const remainingReward = await marketplaceContract.getRemainingReward(
      assetContract.address,
      1
    );

    expect(afterClaim.sub(beforeClaim)).to.eq(actualReward);
    expect(remainingReward).to.eq(0);
  });

  it("Should revert to buy an asset after due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      asset.dueDate
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(
      marketplaceContract.connect(buyer).buy(assetContract.address, 1)
    ).to.revertedWith("Due date has passed");
  });

  it("Should create an asset settle the asset after due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        0,
        (await now()) + 100
      )
    )
      .to.emit(marketplaceContract, "AssetListed")
      .withArgs(assetContract.address, user1.address, 1);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.address, asset.assetPrice);

    await expect(
      await marketplaceContract.connect(buyer).buy(assetContract.address, 1)
    ).not.to.be.reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(buyer.address);

    await time.increase(1000);

    expect(await marketplaceContract.settleAsset(assetContract.address, 1))
      .to.emit(assetContract, "AssetSettled")
      .withArgs(1);

    const afterSettle = await stableTokenContract.balanceOf(buyer.address);

    expect(afterSettle.sub(beforeSettle)).to.be.equal(asset.assetPrice);
  });

  it("Should get remaining zero reward after due date", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    expect(
      await marketplaceContract.createAsset(
        user1.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(marketplaceContract, "AssetListed")
      .withArgs(assetContract.address, user1.address, 1);

    await time.increase(YEAR);

    const expectedReward = 0;

    const actualReward = await marketplaceContract.getRemainingReward(
      assetContract.address,
      1
    );

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should create asset and selling it for 2 times and apply buying fees", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      (await now()) + 100
    );

    await marketplaceContract.setBuyingFee(1000);
    await marketplaceContract.setInitialFee(2000);

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

    await marketplaceContract.connect(buyer).buy(assetContract.address, 1);

    await marketplaceContract
      .connect(buyer)
      .relist(assetContract.address, 1, asset.assetPrice);
    const after1stBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await assetContract
      .connect(buyer)
      .approve(marketplaceContract.address, 1, 1, 1);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.address, 2 * asset.assetPrice);

    const before2ndBuy = await stableTokenContract.balanceOf(feeWallet.address);

    await expect(
      await marketplaceContract.connect(user1).buy(assetContract.address, 1)
    ).not.to.be.reverted;

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
    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      (await now()) + 100
    );

    await marketplaceContract.createAsset(
      user1.address,
      2,
      asset.assetPrice,
      asset.rewardApr,
      (await now()) + 100
    );

    const totalStableTokenAmount = asset.assetPrice.add(asset.assetPrice);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, totalStableTokenAmount);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .batchBuy([assetContract.address, assetContract.address], [1, 2])
    ).not.to.be.reverted;

    expect(await stableTokenContract.balanceOf(treasuryWallet.address)).to.eq(
      totalStableTokenAmount
    );

    expect(
      await assetContract.subIdBalanceOf(marketplaceContract.address, 1)
    ).to.eq(1);
    expect(
      await assetContract.subIdBalanceOf(marketplaceContract.address, 2)
    ).to.eq(1);
  });

  it("Should revert batch buy without array parity", async function () {
    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy([assetContract.address], [1, 2])
    ).to.be.revertedWith("No array parity");
  });

  it("Should revert when asset is not relisted", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await marketplaceContract.createAsset(
      user1.address,
      1,
      asset.assetPrice,
      asset.rewardApr,
      (await now()) + 100
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.address, asset.assetPrice);

    await marketplaceContract.connect(buyer).buy(assetContract.address, 1);

    await expect(
      marketplaceContract.connect(user1).buy(assetContract.address, 1)
    ).to.be.revertedWith("Asset is not relisted");
  });

  it("Should receive batch create4d assets and erc1155 tokens", async function () {
    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.address
    );

    await marketplaceContract.batchCreateAsset(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [asset.assetPrice, asset.assetPrice, asset.assetPrice],
      [asset.rewardApr, asset.rewardApr, asset.rewardApr],
      [asset.dueDate, asset.dueDate, asset.dueDate]
    );

    await asset1155Contract.mintBatch(user1.address, [1, 2, 3], [1, 1, 1]);

    await assetContract
      .connect(user1)
      .safeBatchTransferFrom(
        user1.address,
        marketplaceContract.address,
        [1, 2, 3],
        [1, 1, 1],
        [1, 1, 1],
        "0x"
      );

    await asset1155Contract
      .connect(user1)
      .safeBatchTransferFrom(
        user1.address,
        marketplaceContract.address,
        [1, 2, 3],
        [1, 1, 1],
        "0x"
      );
  });
});
