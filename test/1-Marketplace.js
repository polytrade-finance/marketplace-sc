const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const {
  property,
  asset,
  MarketplaceAccess,
  OriginatorAccess,
  AssetManagerAccess,
  DAY,
  YEAR,
  nearSettleAsset,
  zeroPriceAsset,
  nearSettleProperty,
} = require("./data");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");

describe("Marketplace", function () {
  let assetContract;
  let invoiceContract;
  let propertyContract;
  let stableTokenContract;
  let marketplaceContract;
  let deployer;
  let user1;
  let buyer;
  let treasuryWallet;
  let feeWallet;
  let newTreasuryWallet;
  let newFeeWallet;

  beforeEach(async () => {
    [
      deployer,
      user1,
      buyer,
      treasuryWallet,
      feeWallet,
      newTreasuryWallet,
      newFeeWallet,
    ] = await ethers.getSigners();

    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PAC",
      "2.2",
      "https://ipfs.io/ipfs"
    );

    await assetContract.waitForDeployment();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
    ).deploy("USD Dollar", "USDC", 18, buyer.getAddress(), 200000);

    await stableTokenContract.decimals();

    marketplaceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("Marketplace"),
      [
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
        await feeWallet.getAddress(),
      ]
    );

    invoiceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("InvoiceAsset"),
      [
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
      ]
    );

    propertyContract = await upgrades.deployProxy(
      await ethers.getContractFactory("PropertyAsset"),
      [
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
      ]
    );

    await assetContract.setBaseURI(2, "https://ipfs.io/ipfs");
    await assetContract
      .connect(buyer)
      .setApprovalForAll(marketplaceContract.getAddress(), true);

    await assetContract
      .connect(user1)
      .setApprovalForAll(marketplaceContract.getAddress(), true);

    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.getAddress()
    );

    await assetContract.grantRole(
      AssetManagerAccess,
      invoiceContract.getAddress()
    );

    await assetContract.grantRole(
      AssetManagerAccess,
      propertyContract.getAddress()
    );

    await propertyContract.grantRole(OriginatorAccess, deployer.getAddress());

    await invoiceContract.grantRole(OriginatorAccess, deployer.getAddress());
  });

  it("Should create property successfully", async function () {
    await propertyContract.createProperty(
      await user1.getAddress(),
      1,
      1,
      property
    );

    expect(await assetContract.subIdBalanceOf(user1.getAddress(), 1)).to.eq(
      10000
    );

    expect(await assetContract.tokenURI(1, 1)).to.eq(
      `https://ipfs.io/ipfs${1}`
    );
  });

  it("Should create asset successfully", async function () {
    await invoiceContract.createInvoice(await user1.getAddress(), 1, 1, asset);

    expect(await assetContract.subIdBalanceOf(user1.getAddress(), 1)).to.eq(
      10000
    );

    expect(await assetContract.tokenURI(1, 1)).to.eq(
      `https://ipfs.io/ipfs${1}`
    );
  });

  it("Should revert on burning asset by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(buyer)
        .burnInvoice(buyer.getAddress(), 1, 1, 10000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );

    await expect(
      propertyContract
        .connect(buyer)
        .burnProperty(buyer.getAddress(), 1, 1, 10000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await buyer.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to initialize the contract twice", async function () {
    await expect(
      marketplaceContract.initialize(
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
        await feeWallet.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");

    await expect(
      invoiceContract.initialize(
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        await stableTokenContract.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");

    await expect(
      propertyContract.initialize(
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        await stableTokenContract.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");
  });

  it("Should revert to create asset with invalid owner address", async function () {
    await expect(
      propertyContract.createProperty(ethers.ZeroAddress, 1, 1, property)
    ).to.revertedWith("DLT: mint to the zero address");
  });

  it("Batch create invoice", async function () {
    await invoiceContract.batchCreateInvoice(
      [
        await user1.getAddress(),
        await user1.getAddress(),
        await user1.getAddress(),
      ],
      [1, 2, 3],
      [1, 2, 3],
      [asset, asset, asset]
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 1, 1)).to.eq(
      10000
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 2, 2)).to.eq(
      10000
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 3, 3)).to.eq(
      10000
    );
  });

  it("Batch create property", async function () {
    await propertyContract.batchCreateProperty(
      [
        await user1.getAddress(),
        await user1.getAddress(),
        await user1.getAddress(),
      ],
      [1, 2, 3],
      [1, 2, 3],
      [property, property, property]
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 1, 1)).to.eq(
      10000
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 2, 2)).to.eq(
      10000
    );

    expect(await assetContract.subBalanceOf(user1.getAddress(), 3, 3)).to.eq(
      10000
    );
  });

  it("Should revert Batch create assets on wrong array parity", async function () {
    await expect(
      invoiceContract.batchCreateInvoice(
        [
          await user1.getAddress(),
          await user1.getAddress(),
          await user1.getAddress(),
        ],
        [1, 2],
        [1, 2, 3],
        [asset, asset, asset]
      )
    ).to.be.revertedWith("No array parity");

    await expect(
      propertyContract.batchCreateProperty(
        [user1.getAddress(), user1.getAddress()],
        [1, 2, 3],
        [1, 2, 3],
        [property, property, property]
      )
    ).to.be.revertedWith("No array parity");
  });

  it("Should revert on batch creating assets by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .batchCreateInvoice(
          [
            await user1.getAddress(),
            await user1.getAddress(),
            await user1.getAddress(),
          ],
          [1, 2, 3],
          [1, 2, 3],
          [asset, asset, asset]
        )
    ).to.be.reverted;

    await expect(
      propertyContract
        .connect(user1)
        .batchCreateProperty(
          [
            await user1.getAddress(),
            await user1.getAddress(),
            await user1.getAddress(),
          ],
          [1, 2, 3],
          [1, 2, 3],
          [property, property, property]
        )
    ).to.be.reverted;
  });

  it("Should return zero rewards for minted invoice with zero price", async function () {
    await invoiceContract.createInvoice(
      await user1.getAddress(),
      1,
      1,
      zeroPriceAsset
    );

    const expectedReward = 0;
    const actualReward = await invoiceContract.getRemainingReward(1, 1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should revert on creating minted asset", async function () {
    await invoiceContract.createInvoice(await user1.getAddress(), 1, 1, asset);

    await propertyContract.createProperty(
      await user1.getAddress(),
      2,
      1,
      property
    );

    await expect(
      invoiceContract.createInvoice(await user1.getAddress(), 1, 1, asset)
    ).to.revertedWith("Invoice already created");

    await expect(
      propertyContract.createProperty(await user1.getAddress(), 2, 1, property)
    ).to.revertedWith("Property already created");
  });

  it("Should revert on passing invalid asset collection Address", async function () {
    const factory = await ethers.getContractFactory("Marketplace");

    await expect(
      upgrades.deployProxy(factory, [
        ethers.ZeroAddress,
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
        await feeWallet.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid asset collection Address to Asset contracts", async function () {
    const factory = await ethers.getContractFactory("InvoiceAsset");

    await expect(
      upgrades.deployProxy(factory, [
        await marketplaceContract.getAddress(),
        ethers.ZeroAddress,
        await stableTokenContract.getAddress(),
      ])
    ).to.be.reverted;

    const factory2 = await ethers.getContractFactory("PropertyAsset");

    await expect(
      upgrades.deployProxy(factory2, [
        await marketplaceContract.getAddress(),
        ethers.ZeroAddress,
        await stableTokenContract.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid marketpalce Address to Asset contracts", async function () {
    const factory = await ethers.getContractFactory("InvoiceAsset");

    await expect(
      upgrades.deployProxy(factory, [
        ethers.ZeroAddress,
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
      ])
    ).to.be.reverted;

    const factory2 = await ethers.getContractFactory("PropertyAsset");

    await expect(
      upgrades.deployProxy(factory2, [
        ethers.ZeroAddress,
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid token Address to Asset contracts", async function () {
    const factory = await ethers.getContractFactory("InvoiceAsset");

    await expect(
      upgrades.deployProxy(factory, [
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.be.reverted;

    const factory2 = await ethers.getContractFactory("PropertyAsset");

    await expect(
      upgrades.deployProxy(factory2, [
        await marketplaceContract.getAddress(),
        await assetContract.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing non-compatible asset collection Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await stableTokenContract.getAddress(), // non compatible to asset contract
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
        await feeWallet.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid stable token address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await assetContract.getAddress(),
        ethers.ZeroAddress,
        await treasuryWallet.getAddress(),
        await feeWallet.getAddress(),
      ])
    ).to.revertedWith("Invalid address");
  });

  it("Should revert on listing an asset without ownership", async function () {
    await expect(
      marketplaceContract.connect(user1).list(1, 1, asset.price, 100)
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert on listing with zero minimum fraction ot buy", async function () {
    await expect(
      marketplaceContract.connect(user1).list(1, 1, asset.price, 0)
    ).to.be.revertedWith("Min. fraction can not be zero");
  });

  it("Should revert on settling an asset for wrong owner - Invoice", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await time.increase(1000);

    await expect(
      invoiceContract.settleInvoice(1, 1, buyer.getAddress())
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert on settling an asset for wrong owner - Property", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await time.increase(1000);

    await expect(
      propertyContract.settleProperty(1, 1, 100, buyer.getAddress())
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert on listing without enough balance to sell", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 100);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * asset.price);

    await marketplaceContract.connect(buyer).buy(1, 1, 100, user1.getAddress());

    await expect(
      marketplaceContract.connect(buyer).list(1, 1, asset.price, 2 * 100)
    ).to.be.revertedWith("Min. fraction > Balance");
  });

  it("Should revert on listing and buying with less than Min. fraction", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 100);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await expect(
      marketplaceContract.connect(buyer).buy(1, 1, 99, user1.getAddress())
    ).to.be.revertedWith("Fraction to buy < Min. fraction");
  });

  it("Should revert on listing and buying without enough balance to sell", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 100);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await marketplaceContract.connect(buyer).buy(1, 1, 100, user1.getAddress());

    await marketplaceContract.connect(buyer).list(1, 1, asset.price, 100);

    await expect(
      marketplaceContract.connect(user1).buy(1, 1, 2 * 100, buyer.getAddress())
    ).to.be.revertedWith("Not enough fraction to buy");
  });

  it("Should revert on passing invalid treasury wallet Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        ethers.ZeroAddress,
        await feeWallet.getAddress(),
      ])
    ).to.revertedWith("Invalid wallet address");
  });

  it("Should revert on passing invalid fee wallet Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.revertedWith("Invalid wallet address");
  });

  it("Should return the listed info struct", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    const info = await marketplaceContract.getListedInfo(
      user1.getAddress(),
      1,
      1
    );

    expect(info.salePrice).to.eq(asset.price);
    expect(info.minFraction).to.eq(1000);
  });

  it("Should return the invoice info struct", async function () {
    await invoiceContract.createInvoice(await user1.getAddress(), 1, 1, asset);

    const info = await invoiceContract.getInvoiceInfo(1, 1);

    expect(info.price).to.eq(asset.price);
    expect(info.fractions).to.eq(asset.fractions);
    expect(info.rewardApr).to.eq(asset.rewardApr);
    expect(info.dueDate).to.eq(asset.dueDate);
  });

  it("Should return the property info struct", async function () {
    await propertyContract.createProperty(user1.getAddress(), 1, 1, property);

    const propInfo = await propertyContract.getPropertyInfo(1, 1);

    expect(propInfo.price).to.eq(property.price);
    expect(propInfo.dueDate).to.eq(property.dueDate);
    expect(propInfo.fractions).to.eq(property.fractions);
    expect(propInfo.size).to.eq(property.size);
    expect(propInfo.rooms).to.eq(property.rooms);
    expect(propInfo.bathrooms).to.eq(property.bathrooms);
    expect(propInfo.constructionDate).to.eq(property.constructionDate);
    expect(propInfo.country).to.eq(property.country);
    expect(propInfo.city).to.eq(property.city);
    expect(propInfo.location).to.eq(property.location);
  });

  it("Should return the asset contract address while calling getAssetCollection()", async function () {
    expect(await marketplaceContract.getAssetCollection()).to.eq(
      await assetContract.getAddress()
    );
  });

  it("Should return the stable token contract address while calling getStableToken()", async function () {
    expect(await marketplaceContract.getStableToken()).to.eq(
      await stableTokenContract.getAddress()
    );
  });

  it("Should return the treasury wallet address while calling getTreasuryWallet()", async function () {
    expect(await marketplaceContract.getTreasuryWallet()).to.eq(
      await treasuryWallet.getAddress()
    );
  });

  it("Should return the fee wallet address while calling getFeeWallet()", async function () {
    expect(await marketplaceContract.getFeeWallet()).to.eq(
      await feeWallet.getAddress()
    );
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
      await marketplaceContract.setTreasuryWallet(
        await newTreasuryWallet.getAddress()
      )
    ).not.to.be.reverted;

    expect(await marketplaceContract.getTreasuryWallet()).to.eq(
      await newTreasuryWallet.getAddress()
    );
  });

  it("Should revert when setting a new treasury wallet by invalid sender address while calling setTreasuryWallet()", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .setTreasuryWallet(newTreasuryWallet.getAddress())
    ).to.be.reverted;
  });

  it("Should revert to set initial fee without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).setInitialFee(1000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to create property without originator role", async function () {
    await expect(
      propertyContract
        .connect(user1)
        .createProperty(await user1.getAddress(), 1, 1, property)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to create asset without originator role", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .createInvoice(await user1.getAddress(), 1, 1, asset)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to settle invoice without originator role", async function () {
    await expect(
      invoiceContract.connect(user1).settleInvoice(1, 1, user1.getAddress())
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to settle property without originator role", async function () {
    await expect(
      propertyContract
        .connect(user1)
        .settleProperty(1, 1, 100, await user1.getAddress())
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to set buying fee without admin role", async function () {
    await expect(
      marketplaceContract.connect(user1).setBuyingFee(1000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to batch settle invoice without originator role", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .batchSettleInvoice([1], [1], [user1.getAddress()])
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to batch settle property without originator role", async function () {
    await expect(
      propertyContract
        .connect(user1)
        .batchSettleProperty([1], [1], [100], [user1.getAddress()])
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should set a new fee wallet address while calling setFeeWallet()", async function () {
    await expect(
      await marketplaceContract.setFeeWallet(await newFeeWallet.getAddress())
    ).not.to.be.reverted;

    expect(await marketplaceContract.getFeeWallet()).to.eq(
      await newFeeWallet.getAddress()
    );
  });

  it("Should revert when setting a new fee wallet by invalid sender address while calling setFeeWallet()", async function () {
    await expect(
      marketplaceContract.connect(user1).setFeeWallet(newFeeWallet.getAddress())
    ).to.be.reverted;
  });

  it("Should revert to settle invoice before due date", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await expect(
      invoiceContract.settleInvoice(1, 1, await user1.getAddress())
    ).to.be.revertedWith("Due date not passed");
  });

  it("Should revert to settle property before due date", async function () {
    await propertyContract.createProperty(user1.getAddress(), 1, 1, property);

    await expect(
      propertyContract.settleProperty(
        1,
        1,
        property.price,
        await user1.getAddress()
      )
    ).to.be.revertedWith("Due date not passed");
  });

  it("Should revert to settle invoice with invalid id", async function () {
    await expect(
      invoiceContract.settleInvoice(1, 1, user1.getAddress())
    ).to.be.revertedWith("Invalid invoice id");
  });

  it("Should revert to settle property with invalid id", async function () {
    await expect(
      propertyContract.settleProperty(1, 1, asset.price, user1.getAddress())
    ).to.be.revertedWith("Invalid property id");
  });

  it("Should revert to settle property with invalid amount", async function () {
    await expect(
      propertyContract.settleProperty(1, 1, 0, user1.getAddress())
    ).to.be.revertedWith("Invalid settle amount");
  });

  it("Should create invoice and selling it to buyer through Marketplace", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(1, 1, 1000, user1.getAddress())
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(asset.price / 10n);

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(
      1000
    );
  });

  it("Should create asset and burn", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);
    await propertyContract.createProperty(user1.getAddress(), 2, 1, property);

    await invoiceContract
      .connect(deployer)
      .burnInvoice(user1.getAddress(), 1, 1, 5000);

    await invoiceContract
      .connect(deployer)
      .burnInvoice(user1.getAddress(), 1, 1, 5000);

    await propertyContract
      .connect(deployer)
      .burnProperty(user1.getAddress(), 2, 1, 1000);

    await propertyContract
      .connect(deployer)
      .burnProperty(user1.getAddress(), 2, 1, 9000);
  });

  it("Should create invoice and selling it to buyer (before due date)", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), asset.price);

    expect(await invoiceContract.getAvailableReward(1, 1)).to.eq(0);

    await marketplaceContract
      .connect(buyer)
      .buy(1, 1, 10000, user1.getAddress());

    const tenure = 10n * DAY;
    await time.increase(tenure);

    const expectedReward = Math.round(
      Number((tenure * asset.price * asset.rewardApr) / (10000n * YEAR))
    );

    const actualReward = await invoiceContract.getAvailableReward(1, 1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    await invoiceContract.getRemainingReward(1, 1);
  });

  it("Should create asset and selling it to buyer (after due date)", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(1, 1, 10000, user1.getAddress())
    ).not.to.be.reverted;

    const tenure = BigInt(asset.dueDate - (await now()));
    await time.increase(YEAR);

    const expectedReward = Math.round(
      Number((tenure * asset.price * asset.rewardApr) / (10000n * YEAR))
    );
    const actualReward = await invoiceContract.getAvailableReward(1, 1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    await invoiceContract.getRemainingReward(1, 1);
  });

  it("Should create an invoice and settle the invoice after due date", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(1, 1, 1000, user1.getAddress())
    ).not.to.be.reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(
      buyer.getAddress()
    );

    await time.increase(1000);

    await invoiceContract.settleInvoice(1, 1, buyer.getAddress());

    const afterSettle = await stableTokenContract.balanceOf(buyer.getAddress());

    expect(afterSettle - beforeSettle).to.be.equal(asset.price / 10n);
  });

  it("Should create a property and settle the property after due date", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(1, 1, 1000, user1.getAddress())
    ).not.to.be.reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(
      buyer.getAddress()
    );

    await time.increase(1000);

    await propertyContract.settleProperty(
      1,
      1,
      property.price,
      buyer.getAddress()
    );

    const afterSettle = await stableTokenContract.balanceOf(buyer.getAddress());

    expect(afterSettle - beforeSettle).to.be.equal(property.price / 10n);
  });

  it("Should get remaining zero reward after due date", async function () {
    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await time.increase(YEAR);

    const expectedReward = 0;

    const actualReward = await invoiceContract.getRemainingReward(1, 1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should create invoice and selling it for 2 times and apply buying fees", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await marketplaceContract.setBuyingFee(1000);
    await marketplaceContract.setInitialFee(2000);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * asset.price);

    const before1stBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    await marketplaceContract
      .connect(buyer)
      .buy(1, 1, 1000, user1.getAddress());

    await marketplaceContract.connect(buyer).list(1, 1, asset.price, 1000 / 10);
    const after1stBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    await assetContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 1, 1, 1);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    const before2ndBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    await expect(
      await marketplaceContract
        .connect(user1)
        .buy(1, 1, 1000 / 10, buyer.getAddress())
    ).not.to.be.reverted;

    const after2ndBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    const expected1stFee = (asset.price * 2000n) / (10000n * 10n);
    const expected2ndFee = (asset.price * 1000n) / (10000n * 100n);

    expect(after1stBuy - before1stBuy).to.eq(expected1stFee);

    expect(after2ndBuy - before2ndBuy).to.eq(expected2ndFee);
  });

  it("Should create multiple assets and selling it to buyer through Marketplace", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await propertyContract.createProperty(
      user1.getAddress(),
      2,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(2, 1, asset.price, 1000);

    const totalStableTokenAmount = asset.price + asset.price;

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), totalStableTokenAmount);

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1],
          [1, 2],
          [1000, 1000],
          [user1.getAddress(), user1.getAddress()]
        )
    ).to.be.revertedWith("No array parity");

    await expect(
      await marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 2],
          [1, 1],
          [1000, 1000],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(totalStableTokenAmount / 10n);

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(
      1000
    );
    expect(await assetContract.subBalanceOf(buyer.getAddress(), 2, 1)).to.eq(
      1000
    );
  });

  it("Should create multiple invoices and batch settle all after due date", async function () {
    await invoiceContract.createInvoice(
      user1.getAddress(),
      1,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

    await invoiceContract.createInvoice(
      user1.getAddress(),
      2,
      1,
      await nearSettleAsset()
    );

    await marketplaceContract.connect(user1).list(2, 1, asset.price, 1000);

    const totalStableTokenAmount = asset.price + asset.price;

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * totalStableTokenAmount);

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 2],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 2],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(2n * totalStableTokenAmount);

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(
      1000 * 10
    );
    expect(await assetContract.subBalanceOf(buyer.getAddress(), 2, 1)).to.eq(
      1000 * 10
    );

    await time.increase(1000);

    await expect(
      invoiceContract.batchSettleInvoice(
        [1, 2],
        [1],
        [buyer.getAddress(), buyer.getAddress()]
      )
    ).to.be.revertedWith("No array parity");

    await invoiceContract.batchSettleInvoice(
      [1, 2],
      [1, 1],
      [buyer.getAddress(), buyer.getAddress()]
    );

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(0);
    expect(await assetContract.subBalanceOf(buyer.getAddress(), 2, 1)).to.eq(0);
  });

  it("Should create multiple properties and batch settle all after due date", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(1, 1, property.price, 1000);

    await propertyContract.createProperty(
      user1.getAddress(),
      2,
      1,
      await nearSettleProperty()
    );

    await marketplaceContract.connect(user1).list(2, 1, property.price, 1000);

    const totalStableTokenAmount = property.price + property.price;

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), 2n * totalStableTokenAmount);

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 2],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 2],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(2n * totalStableTokenAmount);

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(
      1000 * 10
    );
    expect(await assetContract.subBalanceOf(buyer.getAddress(), 2, 1)).to.eq(
      1000 * 10
    );

    await time.increase(1000);

    await expect(
      propertyContract.batchSettleProperty(
        [1, 2],
        [1],
        [property.price, property.price],
        [buyer.getAddress(), buyer.getAddress()]
      )
    ).to.be.revertedWith("No array parity");

    await propertyContract.batchSettleProperty(
      [1, 2],
      [1, 1],
      [property.price, property.price],
      [buyer.getAddress(), buyer.getAddress()]
    );

    expect(await assetContract.subBalanceOf(buyer.getAddress(), 1, 1)).to.eq(0);
    expect(await assetContract.subBalanceOf(buyer.getAddress(), 2, 1)).to.eq(0);
  });

  it("Should revert to buy when asset is not listed", async function () {
    await propertyContract.createProperty(
      user1.getAddress(),
      1,
      1,
      await nearSettleProperty()
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      marketplaceContract.connect(buyer).buy(1, 1, 1000, user1.getAddress())
    ).to.be.revertedWith("Asset is not listed");
  });
});
