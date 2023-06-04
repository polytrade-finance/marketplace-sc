const { expect } = require("chai");
const { ethers } = require("hardhat");
const { asset, MarketplaceAccess } = require("./data");

describe("Asset", function () {
  let assetContract;
  let deployer;
  let user1;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    const AssetFactory = await ethers.getContractFactory("Asset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await assetContract.deployed();
  });

  it("Should create asset successfully", async function () {
    expect(
      await assetContract.createAsset(
        deployer.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(deployer.address, deployer.address, 1);

    expect(await assetContract.mainBalanceOf(deployer.address, 1)).to.eq(1);

    expect(await assetContract.tokenURI(1)).to.eq(`https://ipfs.io/ipfs${1}`);
  });

  it("Should revert on creating minted asset", async function () {
    expect(
      await assetContract.createAsset(
        deployer.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(deployer.address, deployer.address, 1);

    await expect(
      assetContract.createAsset(
        deployer.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("Asset: Already minted");
  });

  it("Should revert on creating asset by invalid caller", async function () {
    await expect(
      assetContract
        .connect(user1)
        .createAsset(
          deployer.address,
          1,
          asset.assetPrice,
          asset.rewardApr,
          asset.dueDate
        )
    ).to.be.reverted;
  });

  it("Should to set new base uri", async function () {
    await expect(assetContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Should revert on calling `settleAsset` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(assetContract.settleAsset(1)).to.be.revertedWithCustomError(
      assetContract,
      "UnsupportedInterface"
    );
  });

  it("Should revert on calling `claimReward` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(assetContract.claimReward(1)).to.be.revertedWithCustomError(
      assetContract,
      "UnsupportedInterface"
    );
  });

  it("Should revert on calling `changeOwner` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      assetContract.changeOwner(user1.address, 1)
    ).to.be.revertedWithCustomError(assetContract, "UnsupportedInterface");
  });

  it("Should revert on calling `relist` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      assetContract.changeOwner(user1.address, 1)
    ).to.be.revertedWithCustomError(assetContract, "UnsupportedInterface");
  });

  it("Should revert to relist asset without marketplace role", async function () {
    await expect(
      assetContract.connect(deployer).relist(1, asset.assetPrice)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to settle asset without marketplace role", async function () {
    await expect(
      assetContract.connect(deployer).settleAsset(1)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to set new base uri by invalid caller", async function () {
    await expect(
      assetContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });

  it("Should revert to update claim status without `MarketplaceAccess` role", async function () {
    await expect(
      assetContract.connect(user1).claimReward(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to change owner without `MarketplaceAccess` role", async function () {
    await expect(
      assetContract.connect(user1).changeOwner(user1.address, 1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to settle asset without `MarketplaceAccess` role", async function () {
    await expect(
      assetContract.connect(user1).claimReward(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to create asset with invalid owner address", async function () {
    await expect(
      assetContract.createAsset(
        ethers.constants.AddressZero,
        1,
        0,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.revertedWith("Invalid owner address");
  });

  it("Batch create assets", async function () {
    await assetContract.batchCreateAsset(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [asset.assetPrice, asset.assetPrice, asset.assetPrice],
      [asset.rewardApr, asset.rewardApr, asset.rewardApr],
      [asset.dueDate, asset.dueDate, asset.dueDate]
    );

    expect(await assetContract.mainBalanceOf(user1.address, 1)).to.eq(1);

    expect(await assetContract.mainBalanceOf(user1.address, 2)).to.eq(1);

    expect(await assetContract.mainBalanceOf(user1.address, 3)).to.eq(1);
  });
  it("Should revert Batch create assets on wrong array parity", async function () {
    await expect(
      assetContract.batchCreateAsset(
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
      assetContract.batchCreateAsset(
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
    await expect(
      assetContract
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
    expect(
      await assetContract.createAsset(
        deployer.address,
        1,
        0,
        asset.rewardApr,
        asset.dueDate
      )
    )
      .to.emit(assetContract, "AssetCreated")
      .withArgs(deployer.address, deployer.address, 1);

    const expectedReward = 0;
    const actualReward = await assetContract.getRemainingReward(1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should return zero rewards for not minted asset", async function () {
    const expectedReward = 0;
    const actualReward = await assetContract.getRemainingReward(2);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should return zero available rewards for not minted asset", async function () {
    const expectedReward = 0;
    const actualReward = await assetContract.getAvailableReward(2);

    expect(actualReward).to.be.equal(expectedReward);
  });
});
