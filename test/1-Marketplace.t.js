const { expect } = require("chai");
const { ethers, upgrades, network } = require("hardhat");
const {
  createProperty,
  createAsset,
  createList,
  MarketplaceAccess,
  OriginatorAccess,
  AssetManagerAccess,
  DAY,
  YEAR,
  nearSettleAsset,
  zeroPriceAsset,
  nearSettleProperty,
} = require("./data.spec");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");
const chainId = network.config.chainId;

const getId = async (contract, owner) => {
  const nonce = await contract.getNonce(owner);
  return BigInt(
    ethers.solidityPackedKeccak256(
      ["uint256", "address", "address", "uint256"],
      [chainId, await contract.getAddress(), owner, nonce]
    )
  );
};

const getIds = async (contract, num, owner) => {
  const nonce = await contract.getNonce(owner);
  const arr = [];
  for (let i = 0; i < num; i++) {
    arr.push(
      BigInt(
        ethers.solidityPackedKeccak256(
          ["uint256", "address", "address", "uint256"],
          [chainId, await contract.getAddress(), owner, nonce + BigInt(i)]
        )
      )
    );
  }
  return arr;
};

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
  let newFeeManager;
  let property;
  let asset;

  beforeEach(async () => {
    [deployer, user1, buyer, treasuryWallet, feeWallet, newTreasuryWallet] =
      await ethers.getSigners();

    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PAC",
      "2.3",
      "https://ipfs.io/ipfs"
    );

    const FeeManagerFactory = await ethers.getContractFactory("FeeManager");
    newFeeManager = await FeeManagerFactory.deploy(
      0,
      0,
      await feeWallet.getAddress()
    );

    await newFeeManager.waitForDeployment();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
    ).deploy("USD Dollar", "USDC", 18, buyer.getAddress(), 200000);

    await stableTokenContract.decimals();

    property = await createProperty(stableTokenContract.getAddress());
    asset = await createAsset(stableTokenContract.getAddress());

    marketplaceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("Marketplace"),
      [await assetContract.getAddress(), await newFeeManager.getAddress()]
    );

    invoiceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("InvoiceAsset"),
      [
        await assetContract.getAddress(),
        await treasuryWallet.getAddress(),
        await marketplaceContract.getAddress(),
      ]
    );

    propertyContract = await upgrades.deployProxy(
      await ethers.getContractFactory("PropertyAsset"),
      [await assetContract.getAddress(), await treasuryWallet.getAddress()]
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

    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.getAddress()
    );
  });

  it("Should create property successfully", async function () {
    const id = await getId(propertyContract, await user1.getAddress());

    await propertyContract.createProperty(await user1.getAddress(), property);
    await assetContract.setBaseURI(id, "https://ipfs.io/ipfs");

    expect(await assetContract.subIdBalanceOf(user1.getAddress(), id)).to.eq(
      10000
    );

    expect(await assetContract.tokenURI(id, 1)).to.eq(
      `https://ipfs.io/ipfs${1}`
    );
  });

  it("Should create asset successfully", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());

    await invoiceContract.createInvoice(asset);
    await assetContract.setBaseURI(id, "https://ipfs.io/ipfs");

    expect(
      await assetContract.subIdBalanceOf(invoiceContract.getAddress(), id)
    ).to.eq(10000);

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
      propertyContract.connect(buyer).burnProperty(buyer.getAddress(), 1, 10000)
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
        await feeWallet.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");

    await expect(
      invoiceContract.initialize(
        await assetContract.getAddress(),
        await treasuryWallet.getAddress(),
        await marketplaceContract.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");

    await expect(
      propertyContract.initialize(
        await assetContract.getAddress(),
        await treasuryWallet.getAddress()
      )
    ).to.revertedWith("Initializable: contract is already initialized");
  });

  it("Should revert to create asset with invalid owner address", async function () {
    await expect(
      propertyContract.createProperty(ethers.ZeroAddress, property)
    ).to.revertedWith("DLT: mint to the zero address");
  });

  it("Should revert to create asset with invalid params", async function () {
    await expect(
      propertyContract.createProperty(await user1.getAddress(), {
        price: 0,
        dueDate: (await now()) + 7890000, // add 3 months
        fractions: 10000n,
        settlementToken: await propertyContract.getAddress(),
      })
    ).to.reverted;

    await expect(
      propertyContract.createProperty(await user1.getAddress(), {
        price: 10,
        dueDate: (await now()) - 7890000, // add 3 months
        fractions: 10000n,
        settlementToken: await propertyContract.getAddress(),
      })
    ).to.reverted;

    await expect(
      propertyContract.createProperty(await user1.getAddress(), {
        price: 10,
        dueDate: (await now()) + 7890000, // add 3 months
        fractions: 0,
        settlementToken: await propertyContract.getAddress(),
      })
    ).to.reverted;
  });

  it("Batch create invoice", async function () {
    const ids = await getIds(
      invoiceContract,
      3,
      await invoiceContract.getAddress()
    );
    await invoiceContract.batchCreateInvoice([asset, asset, asset]);

    expect(
      await assetContract.subBalanceOf(invoiceContract.getAddress(), ids[0], 0)
    ).to.eq(10000);

    expect(
      await assetContract.subBalanceOf(invoiceContract.getAddress(), ids[1], 0)
    ).to.eq(10000);

    expect(
      await assetContract.subBalanceOf(invoiceContract.getAddress(), ids[2], 0)
    ).to.eq(10000);
  });

  it("Batch create property", async function () {
    const ids = await getIds(propertyContract, 3, await user1.getAddress());

    await propertyContract.batchCreateProperty(
      [
        await user1.getAddress(),
        await user1.getAddress(),
        await user1.getAddress(),
      ],
      [property, property, property]
    );

    expect(
      await assetContract.subBalanceOf(user1.getAddress(), ids[0], 1)
    ).to.eq(10000);

    expect(
      await assetContract.subBalanceOf(user1.getAddress(), ids[1], 1)
    ).to.eq(10000);

    expect(
      await assetContract.subBalanceOf(user1.getAddress(), ids[2], 1)
    ).to.eq(10000);
  });

  it("Should revert Batch create property on wrong array parity", async function () {
    await expect(
      propertyContract.batchCreateProperty(
        [user1.getAddress(), user1.getAddress()],
        [property, property, property]
      )
    ).to.be.reverted;
  });

  it("Should revert on batch creating assets by invalid caller", async function () {
    await expect(
      invoiceContract.connect(user1).batchCreateInvoice([asset, asset, asset])
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
          [property, property, property]
        )
    ).to.be.reverted;
  });

  it("Should  to create invoice with zero price (can not list with zero price)", async function () {
    await expect(
      invoiceContract.createInvoice(
        await zeroPriceAsset(stableTokenContract.getAddress())
      )
    ).to.be.reverted;

    await expect(
      invoiceContract.createInvoice({
        price: 10,
        dueDate: 10,
        rewardApr: ethers.parseUnits("10", 2), // with 2 decimals
        fractions: 10000n,
        settlementToken: await invoiceContract.getAddress(),
      })
    ).to.be.reverted;

    await expect(
      invoiceContract.createInvoice({
        price: 10,
        dueDate: 9999999999999,
        rewardApr: 0,
        fractions: 10000n,
        settlementToken: await invoiceContract.getAddress(),
      })
    ).to.be.reverted;

    await expect(
      invoiceContract.createInvoice({
        price: 10,
        dueDate: 9999999999999,
        rewardApr: ethers.parseUnits("10", 2), // with 2 decimals
        fractions: 0,
        settlementToken: await invoiceContract.getAddress(),
      })
    ).to.be.reverted;
  });

  it("Should revert on creating minted asset", async function () {
    await assetContract.grantRole(AssetManagerAccess, deployer.getAddress());
    const iId = await getId(
      invoiceContract,
      await invoiceContract.getAddress()
    );
    const pId = await getId(propertyContract, await user1.getAddress());

    await assetContract.createAsset(await user1.getAddress(), iId, 0, 10000);

    await assetContract.createAsset(await user1.getAddress(), pId, 1, 10000);

    await expect(invoiceContract.createInvoice(asset)).to.reverted;

    await expect(
      propertyContract.createProperty(await user1.getAddress(), property)
    ).to.reverted;
  });

  it("Should revert on passing invalid asset collection Address to Asset contracts", async function () {
    const factory = await ethers.getContractFactory("InvoiceAsset");

    await expect(
      upgrades.deployProxy(factory, [
        ethers.ZeroAddress,
        await treasuryWallet.getAddress(),
        await marketplaceContract.getAddress(),
      ])
    ).to.be.reverted;

    const factory2 = await ethers.getContractFactory("PropertyAsset");

    await expect(
      upgrades.deployProxy(factory2, [
        ethers.ZeroAddress,
        await treasuryWallet.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid marketplace Address to Invoice contracts", async function () {
    const factory = await ethers.getContractFactory("InvoiceAsset");

    await expect(
      upgrades.deployProxy(factory, [
        await assetContract.getAddress(),
        await treasuryWallet.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.be.reverted;
  });

  it("Should revert on passing invalid token Address to create assets", async function () {
    const prop = await createProperty(ethers.ZeroAddress);
    const inv = await createAsset(ethers.ZeroAddress);
    await expect(propertyContract.createProperty(user1.getAddress(), prop)).to
      .be.reverted;

    await expect(invoiceContract.createInvoice(inv)).to.be.reverted;
  });

  it("Should revert on passing non-compatible asset collection Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await stableTokenContract.getAddress(), // non compatible to asset contract
        await feeWallet.getAddress(),
      ])
    ).to.be.reverted;
  });

  it("Should revert on listing with invalid token address", async function () {
    await expect(
      marketplaceContract.list(
        1,
        1,
        await createList(asset.price, asset.fractions, 100, ethers.ZeroAddress)
      )
    ).to.reverted;
  });

  it("Should revert on listing with invalid sale price", async function () {
    await expect(
      marketplaceContract.list(
        1,
        1,
        await createList(
          0,
          asset.fractions,
          100,
          await marketplaceContract.getAddress()
        )
      )
    ).to.reverted;
  });

  it("Should revert on passing invalid treasury wallet Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("InvoiceAsset"), [
        await assetContract.getAddress(),
        ethers.ZeroAddress,
        await marketplaceContract.getAddress(),
      ])
    ).to.reverted;

    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("PropertyAsset"), [
        await assetContract.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.reverted;
  });

  it("Should revert on listing an asset without ownership", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .list(
          1,
          1,
          await createList(
            asset.price,
            asset.fractions,
            100,
            stableTokenContract.getAddress()
          )
        )
    ).to.be.reverted;
  });

  it("Should revert on listing with zero minimum fraction ot buy", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .list(
          1,
          1,
          await createList(
            asset.price,
            asset.fractions,
            0,
            stableTokenContract.getAddress()
          )
        )
    ).to.be.reverted;
  });

  it("Should revert on settling an asset for wrong owner - Invoice", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await time.increase(1000);

    await expect(invoiceContract.settleInvoice(id, 0, buyer.getAddress())).to.be
      .reverted;
  });

  it("Should revert on settling an asset for wrong owner - Property", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price,
          asset.fractions,
          1,
          stableTokenContract.getAddress()
        )
      );

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await time.increase(1000);

    await expect(propertyContract.settleProperty(id, 100, buyer.getAddress()))
      .to.be.reverted;
  });

  it("Should revert on listing fractions less than Min. fraction", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * asset.price);

    await marketplaceContract
      .connect(buyer)
      .buy(id, 0, 10000, await invoiceContract.getAddress());

    await expect(
      marketplaceContract
        .connect(buyer)
        .list(
          id,
          1,
          await createList(
            asset.price,
            100,
            200,
            stableTokenContract.getAddress()
          )
        )
    ).to.be.reverted;
  });

  it("Should revert on reentrancy attack on marketpalce buy", async function () {
    const owner = await (
      await ethers.getContractFactory("MockInvoiceOwner")
    ).deploy(marketplaceContract.getAddress());
    await assetContract.grantRole(AssetManagerAccess, deployer.getAddress());

    await assetContract.createAsset(owner.getAddress(), 1, 0, 10000);

    await owner.list(1);

    await expect(
      marketplaceContract
        .connect(user1)
        .buy(1, 0, 100, await owner.getAddress())
    ).to.be.revertedWith("ReentrancyGuard: reentrant call");
  });

  it("Should revert on listing without enough balance to sell", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await marketplaceContract
      .connect(buyer)
      .buy(id, 0, 100, await invoiceContract.getAddress());

    await expect(
      marketplaceContract
        .connect(buyer)
        .list(
          id,
          1,
          await createList(
            asset.price,
            200,
            100,
            stableTokenContract.getAddress()
          )
        )
    ).to.be.reverted;
  });

  it("Should revert on listing and buying with less than Min. fraction", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), asset.price);

    await marketplaceContract
      .connect(user1)
      .buy(id, 0, 10000, await invoiceContract.getAddress());

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price,
          asset.fractions,
          100,
          stableTokenContract.getAddress()
        )
      );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await expect(
      marketplaceContract.connect(buyer).buy(id, 1, 99, user1.getAddress())
    ).to.be.reverted;
  });

  it("Should revert on listing and buying more than listed amount", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), asset.price);

    await marketplaceContract
      .connect(user1)
      .buy(id, 0, 10000, await invoiceContract.getAddress());

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price,
          asset.fractions,
          100,
          stableTokenContract.getAddress()
        )
      );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await expect(
      marketplaceContract.connect(buyer).buy(id, 1, 2 * 100, buyer.getAddress())
    ).to.be.reverted;
  });

  it("Should revert on listing and buying without enough balance to sell", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(user1.getAddress(), asset.price);

    await marketplaceContract
      .connect(user1)
      .buy(id, 0, 100, await invoiceContract.getAddress());

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price,
          100,
          100,
          stableTokenContract.getAddress()
        )
      );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    await assetContract
      .connect(user1)
      .safeTransferFrom(
        await user1.getAddress(),
        await buyer.getAddress(),
        id,
        1,
        1
      );

    await expect(
      marketplaceContract.connect(buyer).buy(id, 1, 100, user1.getAddress())
    ).to.be.reverted;
  });

  it("Should revert on passing invalid fee wallet Address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("Marketplace"), [
        await assetContract.getAddress(),
        ethers.ZeroAddress,
      ])
    ).to.reverted;
  });

  it("Should revert to batch List without array parity", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await expect(
      marketplaceContract.batchList(
        [id],
        [1, 1],
        [
          await createList(
            asset.price,
            asset.fractions,
            1000,
            stableTokenContract.getAddress()
          ),
        ]
      )
    ).to.reverted;

    await expect(
      marketplaceContract.batchList(
        [id, id],
        [1, 1],
        [
          await createList(
            asset.price,
            asset.fractions,
            1000,
            stableTokenContract.getAddress()
          ),
        ]
      )
    ).to.reverted;
  });

  it("Should revert to batch List more than 30 limit", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await expect(
      marketplaceContract.batchList([id], Array(31).fill(1), [
        await createList(
          asset.price,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        ),
      ])
    ).to.reverted;
  });

  it("Should revert to batch Unlist without array parity", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await expect(marketplaceContract.batchUnlist([id], [1, 1])).to.reverted;
  });

  it("Should revert to batch Buy and Unlist more than 30 limit", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await expect(marketplaceContract.batchUnlist([id], Array(31).fill(1))).to
      .reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1],
          Array(31).fill(1),
          [1000, 1000],
          [user1.getAddress(), user1.getAddress()]
        )
    ).to.be.reverted;
  });

  it("Should revert to unlist not listed assets", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());

    await expect(marketplaceContract.unlist(id, 1)).to.reverted;
  });

  it("Should batch create properties and batch list", async function () {
    const ids = await getIds(propertyContract, 3, await user1.getAddress());

    await propertyContract.batchCreateProperty(
      [
        await user1.getAddress(),
        await user1.getAddress(),
        await user1.getAddress(),
      ],
      [property, property, property]
    );

    const list = await createList(
      asset.price,
      asset.fractions,
      1000,
      stableTokenContract.getAddress()
    );

    await marketplaceContract
      .connect(user1)
      .batchList([ids[0], ids[1], ids[2]], [1, 1, 1], [list, list, list]);
  });

  it("Should batch create properties and batch list and unlisted", async function () {
    const ids = await getIds(propertyContract, 3, await user1.getAddress());

    await propertyContract.batchCreateProperty(
      [
        await user1.getAddress(),
        await user1.getAddress(),
        await user1.getAddress(),
      ],
      [property, property, property]
    );

    const list = await createList(
      asset.price,
      asset.fractions,
      1000,
      stableTokenContract.getAddress()
    );

    await marketplaceContract
      .connect(user1)
      .batchList([ids[0], ids[1], ids[2]], [1, 1, 1], [list, list, list]);

    await marketplaceContract
      .connect(user1)
      .batchUnlist([ids[0], ids[1], ids[2]], [1, 1, 1]);
  });

  it("Should return the listed info struct", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    const info = await marketplaceContract.getListedInfo(
      invoiceContract.getAddress(),
      id,
      0
    );

    expect(info.salePrice).to.eq(asset.price / asset.fractions);
    expect(info.minFraction).to.eq(1);
  });

  it("Should return the deleted unlisted info struct", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(await user1.getAddress(), property);

    const list = await createList(
      asset.price,
      asset.fractions,
      1000,
      stableTokenContract.getAddress()
    );

    await marketplaceContract.connect(user1).list(id, 1, list);

    await marketplaceContract.connect(user1).unlist(id, 1);

    const info = await marketplaceContract.getListedInfo(
      invoiceContract.getAddress(),
      id,
      0
    );

    expect(info.salePrice).to.eq(0);
    expect(info.minFraction).to.eq(0);
  });

  it("Should return the batch listed info struct", async function () {
    const ids = await getIds(
      invoiceContract,
      3,
      await invoiceContract.getAddress()
    );
    await invoiceContract.createInvoice(asset);
    await invoiceContract.createInvoice(asset);
    await invoiceContract.createInvoice(asset);

    const info1 = await marketplaceContract.getListedInfo(
      invoiceContract.getAddress(),
      ids[0],
      0
    );

    const info2 = await marketplaceContract.getListedInfo(
      invoiceContract.getAddress(),
      ids[1],
      0
    );

    const info3 = await marketplaceContract.getListedInfo(
      invoiceContract.getAddress(),
      ids[2],
      0
    );

    expect(info1.salePrice).to.eq(asset.price / asset.fractions);
    expect(info1.minFraction).to.eq(1);
    expect(info2.salePrice).to.eq(asset.price / asset.fractions);
    expect(info2.minFraction).to.eq(1);
    expect(info3.salePrice).to.eq(asset.price / asset.fractions);
    expect(info3.minFraction).to.eq(1);
  });

  it("Should return the invoice info struct", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    const info = await invoiceContract.getInvoiceInfo(id);

    expect(info.price).to.eq(asset.price);
    expect(info.fractions).to.eq(asset.fractions);
    expect(info.rewardApr).to.eq(asset.rewardApr);
    expect(info.dueDate).to.eq(asset.dueDate);
  });

  it("Should return the property info struct", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(user1.getAddress(), property);

    const propInfo = await propertyContract.getPropertyInfo(id);

    expect(propInfo.price).to.eq(property.price);
    expect(propInfo.dueDate).to.eq(property.dueDate);
    expect(propInfo.fractions).to.eq(property.fractions);
  });

  it("Should return the asset contract address while calling getAssetCollection()", async function () {
    expect(await marketplaceContract.getAssetCollection()).to.eq(
      await assetContract.getAddress()
    );
  });

  it("Should return the treasury wallet address while calling getTreasuryWallet()", async function () {
    expect(await invoiceContract.getTreasuryWallet()).to.eq(
      await treasuryWallet.getAddress()
    );

    expect(await propertyContract.getTreasuryWallet()).to.eq(
      await treasuryWallet.getAddress()
    );
  });

  it("Should set a new treasury wallet address while calling setTreasuryWallet()", async function () {
    await expect(
      await invoiceContract.setTreasuryWallet(
        await newTreasuryWallet.getAddress()
      )
    ).not.to.be.reverted;

    expect(await invoiceContract.getTreasuryWallet()).to.eq(
      await newTreasuryWallet.getAddress()
    );

    await expect(
      await propertyContract.setTreasuryWallet(
        await newTreasuryWallet.getAddress()
      )
    ).not.to.be.reverted;

    expect(await propertyContract.getTreasuryWallet()).to.eq(
      await newTreasuryWallet.getAddress()
    );
  });

  it("Should revert when setting a new treasury wallet by invalid sender address while calling setTreasuryWallet()", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .setTreasuryWallet(newTreasuryWallet.getAddress())
    ).to.be.reverted;

    await expect(
      propertyContract
        .connect(user1)
        .setTreasuryWallet(newTreasuryWallet.getAddress())
    ).to.be.reverted;
  });

  it("Should revert to create property without originator role", async function () {
    await expect(
      propertyContract
        .connect(user1)
        .createProperty(await user1.getAddress(), property)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to create asset without originator role", async function () {
    await expect(
      invoiceContract.connect(user1).createInvoice(asset)
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
        .settleProperty(1, 100, await user1.getAddress())
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
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
        .batchSettleProperty([1], [100], [user1.getAddress()])
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${OriginatorAccess}`
    );
  });

  it("Should revert to create sub id on invoice without marketplace role", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .onSubIdCreation(user1.getAddress(), 1, 10000)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should set a new fee manager address while calling setFeeManager()", async function () {
    await expect(
      await marketplaceContract.setFeeManager(await newFeeManager.getAddress())
    ).not.to.be.reverted;

    expect(await marketplaceContract.getFeeManager()).to.eq(
      await newFeeManager.getAddress()
    );
  });

  it("Should revert when setting a new fee manager by invalid caller address while calling setFeeManager()", async function () {
    await expect(
      marketplaceContract
        .connect(user1)
        .setFeeManager(newFeeManager.getAddress())
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert to settle invoice before due date", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await expect(
      invoiceContract.settleInvoice(id, 0, await invoiceContract.getAddress())
    ).to.be.reverted;
  });

  it("Should revert to settle property before due date", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(user1.getAddress(), property);

    await expect(
      propertyContract.settleProperty(
        id,
        property.price,
        await user1.getAddress()
      )
    ).to.be.reverted;
  });

  it("Should revert to settle invoice with invalid id", async function () {
    await expect(invoiceContract.settleInvoice(1, 1, user1.getAddress())).to.be
      .reverted;
  });

  it("Should revert to settle property with invalid id", async function () {
    await expect(
      propertyContract.settleProperty(1, asset.price, user1.getAddress())
    ).to.be.reverted;
  });

  it("Should revert to settle property with invalid amount", async function () {
    await expect(propertyContract.settleProperty(1, 0, user1.getAddress())).to
      .be.reverted;
  });

  it("Should create invoice and selling it to buyer through Marketplace", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(id, 0, 1000, invoiceContract.getAddress())
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(asset.price / 10n);

    expect(await assetContract.subBalanceOf(buyer.getAddress(), id, 1)).to.eq(
      1000
    );
  });

  it("Should create invoice and increment sub Id after buy", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    expect(await invoiceContract.getCurrentSubId(id)).to.eq(0);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(id, 0, 1000, invoiceContract.getAddress())
    ).not.to.be.reverted;

    expect(await invoiceContract.getCurrentSubId(id)).to.eq(1);
  });

  it("Should create asset and burn", async function () {
    const iId = await getId(
      invoiceContract,
      await invoiceContract.getAddress()
    );
    const pId = await getId(propertyContract, await user1.getAddress());
    await invoiceContract.createInvoice(asset);
    await propertyContract.createProperty(user1.getAddress(), property);

    await invoiceContract
      .connect(deployer)
      .burnInvoice(invoiceContract.getAddress(), iId, 0, 5000);

    await invoiceContract
      .connect(deployer)
      .burnInvoice(invoiceContract.getAddress(), iId, 0, 5000);

    await propertyContract
      .connect(deployer)
      .burnProperty(user1.getAddress(), pId, 1000);

    await propertyContract
      .connect(deployer)
      .burnProperty(user1.getAddress(), pId, 9000);
  });

  it("Should create invoice and selling it to buyer (before due date)", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());

    expect(await invoiceContract.getAvailableReward(id, 0)).to.eq(0);

    await invoiceContract.createInvoice(asset);

    expect(await invoiceContract.getRemainingReward(id, 1)).to.be.eq(0);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), asset.price);

    expect(await invoiceContract.getAvailableReward(id, 0)).to.eq(0);

    await marketplaceContract
      .connect(buyer)
      .buy(id, 0, 10000, invoiceContract.getAddress());

    const tenure = 10n * DAY;
    await time.increase(tenure);

    const expectedReward = Math.round(
      Number((tenure * asset.price * asset.rewardApr) / (10000n * YEAR))
    );

    const actualReward = await invoiceContract.getAvailableReward(id, 1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    await invoiceContract.getRemainingReward(id, 1);
  });

  it("Should create asset and selling it to buyer (after due date)", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(id, 0, 10000, invoiceContract.getAddress())
    ).not.to.be.reverted;

    const tenure = BigInt(asset.dueDate - (await now()));
    await time.increase(YEAR);

    const expectedReward = Math.round(
      Number((tenure * asset.price * asset.rewardApr) / (10000n * YEAR))
    );
    const actualReward = await invoiceContract.getAvailableReward(id, 1);

    expect(actualReward).to.be.within(expectedReward - 1, expectedReward + 1);

    await invoiceContract.getRemainingReward(id, 1);
  });

  it("Should create an invoice and settle the invoice after due date", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(id, 0, 1000, invoiceContract.getAddress())
    ).not.to.be.reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(
      buyer.getAddress()
    );

    await time.increase(1000);

    await invoiceContract.settleInvoice(id, 1, buyer.getAddress());

    const afterSettle = await stableTokenContract.balanceOf(buyer.getAddress());

    expect(afterSettle - beforeSettle).to.be.equal(asset.price / 10n);
  });

  it("Should create a property and settle the property after due date", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), asset.price);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), asset.price);

    await expect(
      await marketplaceContract
        .connect(buyer)
        .buy(id, 1, 1000, user1.getAddress())
    ).not.to.be.reverted;

    await time.increase(10);

    const beforeSettle = await stableTokenContract.balanceOf(
      buyer.getAddress()
    );

    await time.increase(1000);

    await propertyContract.settleProperty(
      id,
      property.price,
      buyer.getAddress()
    );

    const afterSettle = await stableTokenContract.balanceOf(buyer.getAddress());

    expect(afterSettle - beforeSettle).to.be.equal(property.price / 10n);
  });

  it("Should get remaining zero reward after due date", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());
    await invoiceContract.createInvoice(asset);

    await time.increase(YEAR);

    const expectedReward = 0;

    const actualReward = await invoiceContract.getRemainingReward(id, 0);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should get remaining zero reward for not created invoice", async function () {
    const id = await getId(invoiceContract, await invoiceContract.getAddress());

    const expectedReward = 0;

    const actualReward = await invoiceContract.getRemainingReward(id, 0);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should create invoice and selling it for 2 times and apply buying fees", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    await newFeeManager.setDefaultFees(2000, 1000);

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
      .buy(id, 1, 1000, user1.getAddress());

    await marketplaceContract
      .connect(buyer)
      .list(
        id,
        1,
        await createList(
          asset.price / asset.fractions,
          1000,
          1000 / 10,
          stableTokenContract.getAddress()
        )
      );
    const after1stBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    await assetContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), id, 1, 1);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 2n * asset.price);

    const before2ndBuy = await stableTokenContract.balanceOf(
      feeWallet.getAddress()
    );

    await expect(
      await marketplaceContract
        .connect(user1)
        .buy(id, 1, 1000 / 10, buyer.getAddress())
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
    const ids = await getIds(propertyContract, 2, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        ids[0],
        1,
        await createList(
          asset.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        ids[1],
        1,
        await createList(
          asset.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

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
    ).to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [1, 1],
          [1, 2],
          [1000],
          [user1.getAddress(), user1.getAddress()]
        )
    ).to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy([1, 1], [1, 2], [1000, 1000], [user1.getAddress()])
    ).to.be.reverted;

    await expect(
      await marketplaceContract
        .connect(buyer)
        .batchBuy(
          [ids[0], ids[1]],
          [1, 1],
          [1000, 1000],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    expect(await stableTokenContract.balanceOf(user1.getAddress())).to.eq(
      totalStableTokenAmount / 10n
    );

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 1)
    ).to.eq(1000);
    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 1)
    ).to.eq(1000);
  });

  it("Should create multiple invoices and batch settle all after due date", async function () {
    const ids = await getIds(
      invoiceContract,
      2,
      await invoiceContract.getAddress()
    );
    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    await invoiceContract.createInvoice(
      await nearSettleAsset(stableTokenContract.getAddress())
    );

    const totalStableTokenAmount = asset.price + asset.price;

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), 2n * totalStableTokenAmount);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(invoiceContract.getAddress(), 2n * totalStableTokenAmount);

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [ids[0], ids[1]],
          [0, 0],
          [1000 * 5, 1000 * 5],
          [invoiceContract.getAddress(), invoiceContract.getAddress()]
        )
    ).not.to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [ids[0], ids[1]],
          [0, 0],
          [1000 * 5, 1000 * 5],
          [invoiceContract.getAddress(), invoiceContract.getAddress()]
        )
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(3n * totalStableTokenAmount);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 1)
    ).to.eq(1000 * 5);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 2)
    ).to.eq(1000 * 5);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 1)
    ).to.eq(1000 * 5);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 2)
    ).to.eq(1000 * 5);

    await time.increase(1000);

    await expect(
      invoiceContract.batchSettleInvoice(
        [ids[0]],
        [1],
        [buyer.getAddress(), buyer.getAddress()]
      )
    ).to.be.reverted;

    await expect(
      invoiceContract.batchSettleInvoice([ids[0]], [1, 2], [buyer.getAddress()])
    ).to.be.reverted;

    await invoiceContract.batchSettleInvoice(
      [ids[0], ids[0], ids[1], ids[1]],
      [1, 2, 1, 2],
      [
        buyer.getAddress(),
        buyer.getAddress(),
        buyer.getAddress(),
        buyer.getAddress(),
      ]
    );

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 1)
    ).to.eq(0);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 2)
    ).to.eq(0);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 1)
    ).to.eq(0);

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 2)
    ).to.eq(0);
  });

  it("Should create multiple properties and batch settle all after due date", async function () {
    const ids = await getIds(propertyContract, 2, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        ids[0],
        1,
        await createList(
          property.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await marketplaceContract
      .connect(user1)
      .list(
        ids[1],
        1,
        await createList(
          property.price / asset.fractions,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    const totalStableTokenAmount = property.price + property.price;

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), totalStableTokenAmount);

    await stableTokenContract
      .connect(buyer)
      .transfer(treasuryWallet.getAddress(), 2n * totalStableTokenAmount);

    await stableTokenContract
      .connect(treasuryWallet)
      .approve(propertyContract.getAddress(), 2n * totalStableTokenAmount);

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [ids[0], ids[1]],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    await expect(
      marketplaceContract
        .connect(buyer)
        .batchBuy(
          [ids[0], ids[1]],
          [1, 1],
          [1000 * 5, 1000 * 5],
          [user1.getAddress(), user1.getAddress()]
        )
    ).not.to.be.reverted;

    expect(
      await stableTokenContract.balanceOf(treasuryWallet.getAddress())
    ).to.eq(2n * totalStableTokenAmount);

    expect(await stableTokenContract.balanceOf(user1.getAddress())).to.eq(
      totalStableTokenAmount
    );

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 1)
    ).to.eq(1000 * 10);
    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 1)
    ).to.eq(1000 * 10);

    await time.increase(1000);

    await expect(
      propertyContract.batchSettleProperty(
        [ids[0], ids[1]],
        [property.price],
        [buyer.getAddress(), buyer.getAddress()]
      )
    ).to.be.reverted;

    await expect(
      propertyContract.batchSettleProperty(
        [ids[0], ids[1]],
        [property.price, property.price],
        [buyer.getAddress()]
      )
    ).to.be.reverted;

    await propertyContract.batchSettleProperty(
      [ids[0], ids[1]],
      [property.price, property.price],
      [buyer.getAddress(), buyer.getAddress()]
    );

    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[0], 1)
    ).to.eq(0);
    expect(
      await assetContract.subBalanceOf(buyer.getAddress(), ids[1], 1)
    ).to.eq(0);
  });

  it("Should revert to buy when asset is not listed", async function () {
    const id = await getId(propertyContract, await user1.getAddress());
    await propertyContract.createProperty(
      user1.getAddress(),
      await nearSettleProperty(stableTokenContract.getAddress())
    );

    await stableTokenContract
      .connect(buyer)
      .approve(marketplaceContract.getAddress(), asset.price);

    await expect(
      marketplaceContract.connect(buyer).buy(id, 1, 1000, user1.getAddress())
    ).to.be.reverted;
  });
});
