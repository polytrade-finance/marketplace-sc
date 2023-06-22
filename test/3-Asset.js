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

  it("Should revert on creating asset by invalid caller", async function () {
    await expect(
      assetContract
        .connect(deployer)
        .createAsset(
          deployer.address,
          1,
          asset.assetPrice,
          asset.rewardApr,
          asset.dueDate
        )
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert on calling `createAsset` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      assetContract.createAsset(
        deployer.address,
        1,
        asset.assetPrice,
        asset.rewardApr,
        asset.dueDate
      )
    ).to.be.revertedWithCustomError(assetContract, "UnsupportedInterface");
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

    await expect(assetContract.updateClaim(1)).to.be.revertedWithCustomError(
      assetContract,
      "UnsupportedInterface"
    );
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
      assetContract.connect(user1).updateClaim(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to settle asset without `MarketplaceAccess` role", async function () {
    await expect(
      assetContract.connect(user1).updateClaim(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
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
