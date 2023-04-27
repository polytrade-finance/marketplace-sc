const { expect } = require("chai");
const { ethers } = require("hardhat");
const { invoice1, DECIMALS, settleInvoice1 } = require("./data");

describe("Invoice", function () {
  let formulasContract;
  let invoiceContract;
  let stableCoinContract;

  let deployer;
  let user1;

  beforeEach(async () => {
    [deployer, user1] = await ethers.getSigners();

    const FormulasFactory = await ethers.getContractFactory("Formulas");
    formulasContract = await FormulasFactory.deploy();

    await formulasContract.deployed();

    stableCoinContract = await (
      await ethers.getContractFactory("Token")
    ).deploy("USD Dollar", "USDC", user1.address, 200000);

    const InvoiceFactory = await ethers.getContractFactory("Invoice");
    invoiceContract = await InvoiceFactory.deploy(
      "Polytrade Invoice Collection",
      "PIC",
      "https://ipfs.io/ipfs",
      formulasContract.address,
      stableCoinContract.address
    );

    await invoiceContract.deployed();
  });

  it("Create Invoice successfully", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice1.initialMainMetadata,
        invoice1.initialSubMetadata
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    expect(await invoiceContract.mainBalanceOf(deployer.address, 1)).to.eq(
      ethers.utils.parseUnits("10000", DECIMALS.SIX)
    );

    expect(await invoiceContract.tokenURI(1)).to.eq(`https://ipfs.io/ipfs${1}`);
  });

  it("Revert on Creating minted invoice", async function () {
    expect(
      await invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice1.initialMainMetadata,
        invoice1.initialSubMetadata
      )
    )
      .to.emit(invoiceContract, "InvoiceCreated")
      .withArgs(deployer.address, deployer.address, 1);

    await expect(
      invoiceContract.createInvoice(
        deployer.address,
        1,
        invoice1.initialMainMetadata,
        invoice1.initialSubMetadata
      )
    ).to.be.revertedWith("Invoice: Already minted");
  });

  it("Revert on Batch Creating minted invoice", async function () {
    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address, user1.address],
        [1, 1, 3], // create two mainIds of 1
        [
          invoice1.initialMainMetadata,
          invoice1.initialMainMetadata,
          invoice1.initialMainMetadata,
        ],
        [
          invoice1.initialSubMetadata,
          invoice1.initialSubMetadata,
          invoice1.initialSubMetadata,
        ]
      )
    ).to.be.revertedWith("Invoice: Already minted");
  });

  it("Revert on Creating invoice by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .createInvoice(
          deployer.address,
          1,
          invoice1.initialMainMetadata,
          invoice1.initialSubMetadata
        )
    ).to.be.reverted;
  });

  it("Set new base uri", async function () {
    await expect(invoiceContract.setBaseURI("https://ipfs2.io/ipfs")).to.not.be
      .reverted;
  });

  it("Revert Set new base uri by invalid caller", async function () {
    await expect(
      invoiceContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });

  it("Batch create invoices", async function () {
    await invoiceContract.batchCreateInvoice(
      [user1.address, user1.address, user1.address],
      [1, 2, 3],
      [
        invoice1.initialMainMetadata,
        invoice1.initialMainMetadata,
        invoice1.initialMainMetadata,
      ],
      [
        invoice1.initialSubMetadata,
        invoice1.initialSubMetadata,
        invoice1.initialSubMetadata,
      ]
    );

    expect(await invoiceContract.mainBalanceOf(user1.address, 1)).to.eq(
      ethers.utils.parseUnits("10000", DECIMALS.SIX)
    );

    expect(await invoiceContract.mainBalanceOf(user1.address, 2)).to.eq(
      ethers.utils.parseUnits("10000", DECIMALS.SIX)
    );

    expect(await invoiceContract.mainBalanceOf(user1.address, 3)).to.eq(
      ethers.utils.parseUnits("10000", DECIMALS.SIX)
    );
  });

  it("Revert Batch create invoices on wrong array parity", async function () {
    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address, user1.address],
        [1, 2], // wrong array parity
        [
          invoice1.initialMainMetadata,
          invoice1.initialMainMetadata,
          invoice1.initialMainMetadata,
        ],
        [
          invoice1.initialSubMetadata,
          invoice1.initialSubMetadata,
          // invoice1.initialSubMetadata,  wrong array parity
        ]
      )
    ).to.be.revertedWith("Invoice: No array parity");

    await expect(
      invoiceContract.batchCreateInvoice(
        [user1.address, user1.address], // user1.address  wrong array parity
        [1, 2, 3],
        [
          invoice1.initialMainMetadata,
          invoice1.initialMainMetadata,
          // invoice1.initialMainMetadata,  wrong array parity
        ],
        [
          invoice1.initialSubMetadata,
          invoice1.initialSubMetadata,
          invoice1.initialSubMetadata,
        ]
      )
    ).to.be.revertedWith("Invoice: No array parity");
  });

  it("Revert on Batch Creating invoices by invalid caller", async function () {
    await expect(
      invoiceContract
        .connect(user1)
        .batchCreateInvoice(
          [user1.address, user1.address, user1.address],
          [1, 2, 3],
          [
            invoice1.initialMainMetadata,
            invoice1.initialMainMetadata,
            invoice1.initialMainMetadata,
          ],
          [
            invoice1.initialSubMetadata,
            invoice1.initialSubMetadata,
            invoice1.initialSubMetadata,
          ]
        )
    ).to.be.reverted;
  });

  it("Revert Set new base uri by invalid caller", async function () {
    await expect(
      invoiceContract.connect(user1).setBaseURI("https://ipfs2.io/ipfs")
    ).to.be.reverted;
  });

  it("Settle invoice", async function () {
    await invoiceContract.createInvoice(
      deployer.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    await invoiceContract.setAssetSettledMetadata(
      settleInvoice1.mainId,
      settleInvoice1.paymentReceiptDate,
      settleInvoice1.reservePaidToSupplier,
      settleInvoice1.amountSentToLender
    );
  });

  it("Reject Settlement for any settled invoice", async function () {
    await invoiceContract.createInvoice(
      deployer.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    await expect(
      invoiceContract.setAssetSettledMetadata(
        settleInvoice1.mainId,
        settleInvoice1.paymentReceiptDate,
        settleInvoice1.reservePaidToSupplier,
        settleInvoice1.amountSentToLender
      )
    ).to.not.be.reverted;

    await expect(
      invoiceContract.setAssetSettledMetadata(
        settleInvoice1.mainId,
        settleInvoice1.paymentReceiptDate,
        settleInvoice1.reservePaidToSupplier,
        settleInvoice1.amountSentToLender
      )
    ).to.be.revertedWith("Asset is already settled");
  });

  it("Reject Settlement by invalid caller", async function () {
    await invoiceContract.createInvoice(
      deployer.address,
      1,
      invoice1.initialMainMetadata,
      invoice1.initialSubMetadata
    );

    await expect(
      invoiceContract
        .connect(user1) // he is not the admin
        .setAssetSettledMetadata(
          settleInvoice1.mainId,
          settleInvoice1.paymentReceiptDate,
          settleInvoice1.reservePaidToSupplier,
          settleInvoice1.amountSentToLender
        )
    ).to.be.reverted;
  });
});
