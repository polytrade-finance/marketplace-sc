const { expect } = require("chai");
const { ethers } = require("hardhat");
const { MarketplaceAccess } = require("./data");

describe("Asset", function () {
  let assetContract;
  let deployer;
  let user1;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    const AssetFactory = await ethers.getContractFactory("Asset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PAC",
      "https://ipfs.io/ipfs"
    );

    await assetContract.deployed();
  });

  it("Should revert on creating asset by invalid caller", async function () {
    await expect(
      assetContract.connect(deployer).createAsset(deployer.address, 1)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert on burning asset by invalid caller", async function () {
    await expect(
      assetContract.connect(deployer).burnAsset(deployer.address, 1)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert on calling `createAsset` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      assetContract.createAsset(deployer.address, 1)
    ).to.be.revertedWithCustomError(assetContract, "UnsupportedInterface");
  });

  it("Should revert on calling `burnAsset` without interface support", async function () {
    await assetContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      assetContract.burnAsset(deployer.address, 1)
    ).to.be.revertedWithCustomError(assetContract, "UnsupportedInterface");
  });

  it("Should to set new base uri", async function () {
    await expect(assetContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Should revert to set new base uri by invalid caller", async function () {
    await expect(
      assetContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });
});
