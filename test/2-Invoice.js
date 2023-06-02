const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice, MarketplaceAccess } = require("./data");

describe("Invoice", function () {
  let invoiceContract;
  let deployer;
  let user1;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await invoiceContract.deployed();
  });

  it("Should create invoice successfully", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    expect(await invoiceContract.mainBalanceOf(deployer.address, 1)).to.eq(1);

    expect(await invoiceContract.tokenURI(1)).to.eq(`https://ipfs.io/ipfs${1}`);
  });

  it("Should revert on creating minted invoice", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    await expect(
      invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice.assetPrice,
        invoice.rewardApr,
        invoice.dueDate
      )
    ).to.revertedWith("Invoice: Already minted");
  });

  it("Should revert on creating invoice by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .createInvoice(
          deployer.address,
          1,
          invoice.assetPrice,
          invoice.rewardApr,
          invoice.dueDate
        )
    ).to.be.reverted;
  });

  it("Should to set new base uri", async function () {
    await expect(invoiceContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Should revert on calling `settleInvoice` without interface support", async function () {
    await invoiceContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      invoiceContract.settleInvoice(1)
    ).to.be.revertedWithCustomError(invoiceContract, "UnsupportedInterface");
  });

  it("Should revert on calling `claimReward` without interface support", async function () {
    await invoiceContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(invoiceContract.claimReward(1)).to.be.revertedWithCustomError(
      invoiceContract,
      "UnsupportedInterface"
    );
  });

  it("Should revert on calling `changeOwner` without interface support", async function () {
    await invoiceContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      invoiceContract.changeOwner(user1.address, 1)
    ).to.be.revertedWithCustomError(invoiceContract, "UnsupportedInterface");
  });

  it("Should revert on calling `reList` without interface support", async function () {
    await invoiceContract.grantRole(MarketplaceAccess, deployer.address);

    await expect(
      invoiceContract.changeOwner(user1.address, 1)
    ).to.be.revertedWithCustomError(invoiceContract, "UnsupportedInterface");
  });

  it("Should revert to relist invoice without marketplace role", async function () {
    await expect(
      invoiceContract.connect(deployer).reList(1, invoice.assetPrice)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to settle invoice without marketplace role", async function () {
    await expect(
      invoiceContract.connect(deployer).settleInvoice(1)
    ).to.be.revertedWith(
      `AccessControl: account ${deployer.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to set new base uri by invalid caller", async function () {
    await expect(
      invoiceContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });

  it("Should revert to update claim status without `MarketplaceAccess` role", async function () {
    await expect(
      invoiceContract.connect(user1).claimReward(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to change owner without `MarketplaceAccess` role", async function () {
    await expect(
      invoiceContract.connect(user1).changeOwner(user1.address, 1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to settle invoice without `MarketplaceAccess` role", async function () {
    await expect(
      invoiceContract.connect(user1).claimReward(1)
    ).to.be.revertedWith(
      `AccessControl: account ${user1.address.toLowerCase()} is missing role ${MarketplaceAccess}`
    );
  });

  it("Should revert to create invoice with invalid owner address", async function () {
    await expect(
      invoiceContract.createInvoice(
        ethers.constants.AddressZero,
        1,
        0,
        invoice.rewardApr,
        invoice.dueDate
      )
    ).to.revertedWith("Invalid owner address");
  });

  it("Batch create invoices", async function () {
    await invoiceContract.batchCreateInvoice(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
      [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
      [invoice.dueDate, invoice.dueDate, invoice.dueDate]
    );

    expect(await invoiceContract.mainBalanceOf(user1.address, 1)).to.eq(1);

    expect(await invoiceContract.mainBalanceOf(user1.address, 2)).to.eq(1);

    expect(await invoiceContract.mainBalanceOf(user1.address, 3)).to.eq(1);
  });
  it("Should revert Batch create invoices on wrong array parity", async function () {
    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address, user1.address],
        [1, 2],
        [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
        [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
        [
          invoice.dueDate,
          invoice.dueDate,
          // invoice.dueDate,
        ]
      )
    ).to.be.revertedWith("Invoice: No array parity");

    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address],
        [1, 2, 3],
        [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
        [
          invoice.rewardApr,
          invoice.rewardApr,
          // invoice.rewardApr,
        ],
        [invoice.dueDate, invoice.dueDate, invoice.dueDate]
      )
    ).to.be.revertedWith("Invoice: No array parity");
  });

  it("Should revert on batch creating invoices by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .batchCreateInvoice(
          [user1.address, user1.address, user1.address],
          [1, 2, 3],
          [invoice.assetPrice, invoice.assetPrice, invoice.assetPrice],
          [invoice.rewardApr, invoice.rewardApr, invoice.rewardApr],
          [invoice.dueDate, invoice.dueDate, invoice.dueDate]
        )
    ).to.be.reverted;
  });

  it("Should return zero rewards for minted invoice with zero price", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        0,
        invoice.rewardApr,
        invoice.dueDate
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    const expectedReward = 0;
    const actualReward = await invoiceContract.getRemainingReward(1);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should return zero rewards for not minted invoice", async function () {
    const expectedReward = 0;
    const actualReward = await invoiceContract.getRemainingReward(2);

    expect(actualReward).to.be.equal(expectedReward);
  });

  it("Should return zero available rewards for not minted invoice", async function () {
    const expectedReward = 0;
    const actualReward = await invoiceContract.getAvailableReward(2);

    expect(actualReward).to.be.equal(expectedReward);
  });
});
