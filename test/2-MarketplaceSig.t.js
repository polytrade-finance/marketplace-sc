const { expect } = require("chai");
const { ethers, upgrades, network } = require("hardhat");
const {
  MarketplaceAccess,
  offer,
  AssetManagerAccess,
  OriginatorAccess,
  createAsset,
  createList,
} = require("./data.spec");
const { time } = require("@nomicfoundation/hardhat-network-helpers");
const { now } = require("./helpers");
const {
  domainSeparatorCal,
  calculateOfferHash,
  validateRecoveredAddress,
} = require("./helpers/eip712");

describe("Marketplace Signatures", function () {
  let assetContract;
  let stableTokenContract;
  let marketplaceContract;
  let deployer;
  let user1;
  let offeror;
  let treasuryWallet;
  let feeWallet;
  let invoiceContract;
  let name;
  let version;
  let domainSeparator;
  let signature;
  let params;
  let domainData;
  let offerType;
  let id;
  let asset;
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

  beforeEach(async () => {
    [deployer, user1, offeror, treasuryWallet, feeWallet] =
      await ethers.getSigners();

    name = "Polytrade";
    version = "2.3";
    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PIC",
      "2.3",
      "https://ipfs.io/ipfs"
    );

    await assetContract.waitForDeployment();

    const FeeManagerFactory = await ethers.getContractFactory("FeeManager");
    const FeeManager = await FeeManagerFactory.deploy(
      0,
      0,
      await feeWallet.getAddress()
    );

    await FeeManager.waitForDeployment();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
    ).deploy("USD Dollar", "USDC", 18, offeror.getAddress(), 20000000);

    marketplaceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("Marketplace"),
      [await assetContract.getAddress(), await FeeManager.getAddress()]
    );

    invoiceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("InvoiceAsset"),
      [
        await assetContract.getAddress(),
        await treasuryWallet.getAddress(),
        await marketplaceContract.getAddress(),
      ]
    );

    await assetContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.getAddress()
    );

    await assetContract.grantRole(
      AssetManagerAccess,
      invoiceContract.getAddress()
    );
    id = await getId(invoiceContract, await invoiceContract.getAddress());

    await invoiceContract.grantRole(OriginatorAccess, deployer.getAddress());

    await invoiceContract.grantRole(
      MarketplaceAccess,
      marketplaceContract.getAddress()
    );

    asset = await createAsset(stableTokenContract.getAddress());

    await invoiceContract.createInvoice(asset);

    await stableTokenContract
      .connect(user1)
      .approve(marketplaceContract.getAddress(), 10n * asset.price);

    await stableTokenContract
      .connect(offeror)
      .transfer(user1.getAddress(), 10n * asset.price);

    await marketplaceContract
      .connect(user1)
      .buy(id, 0, asset.fractions, invoiceContract.getAddress());

    await marketplaceContract
      .connect(user1)
      .list(
        id,
        1,
        await createList(
          asset.price / 100n,
          asset.fractions,
          1000,
          stableTokenContract.getAddress()
        )
      );

    await assetContract
      .connect(user1)
      .setApprovalForAll(marketplaceContract.getAddress(), true);

    await stableTokenContract
      .connect(offeror)
      .approve(marketplaceContract.getAddress(), 10n * asset.price);

    domainSeparator = await marketplaceContract.DOMAIN_SEPARATOR();

    domainData = {
      name,
      version,
      chainId,
      verifyingContract: await marketplaceContract.getAddress(),
    };

    offerType = {
      offer: [
        { name: "owner", type: "address" },
        { name: "offeror", type: "address" },
        { name: "offerPrice", type: "uint256" },
        { name: "mainId", type: "uint256" },
        { name: "subId", type: "uint256" },
        { name: "fractionsToBuy", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };
  });

  describe("Counter Offer", function () {
    it("Should return 0 for initial nonce", async function () {
      expect(
        await marketplaceContract.getNonce(user1.getAddress())
      ).to.be.equal("0");
    });

    it("Should return correct domain separator", async function () {
      expect(domainSeparator).to.equal(
        await domainSeparatorCal(
          name,
          version,
          chainId,
          await marketplaceContract.getAddress()
        )
      );
    });

    it("Should buy invoice with owner signed offer", async function () {
      params = {
        owner: await user1.getAddress(),
        offeror: await offeror.getAddress(),
        offerPrice: offer.offerPrice / 10000n,
        mainId: id,
        subId: 1,
        fractionsToBuy: 1000,
        nonce: 0,
        deadline: offer.deadline + BigInt(await now()),
      };

      signature = await user1.signTypedData(domainData, offerType, params);
      // Validate Signature Offchain

      const hash = calculateOfferHash(params);

      validateRecoveredAddress(
        await user1.getAddress(),
        domainSeparator,
        hash,
        signature
      );

      const { r, s, v } = ethers.Signature.from(signature);

      const balanceBeforeBuy = await stableTokenContract.balanceOf(
        offeror.getAddress()
      );

      const user1BalanceBeforeBuy = await stableTokenContract.balanceOf(
        user1.getAddress()
      );

      await marketplaceContract
        .connect(offeror)
        .offer(
          user1.getAddress(),
          offeror.getAddress(),
          offer.offerPrice / 10000n,
          id,
          1,
          1000,
          offer.deadline + BigInt(await now()),
          v,
          r,
          s
        );

      const balanceAfterBuy = await stableTokenContract.balanceOf(
        offeror.getAddress()
      );

      const user1BalanceAfterBuy = await stableTokenContract.balanceOf(
        user1.getAddress()
      );

      expect(balanceBeforeBuy - balanceAfterBuy).to.be.equal(
        offer.offerPrice / 10n
      );

      expect(
        await marketplaceContract.getNonce(user1.getAddress())
      ).to.be.equal("1");
      expect(user1BalanceAfterBuy - user1BalanceBeforeBuy).to.be.equal(
        offer.offerPrice / 10n
      );
    });

    it("Should revert if sender is not offeror", async function () {
      params = {
        owner: await user1.getAddress(),
        offeror: await offeror.getAddress(),
        offerPrice: offer.offerPrice / 100n,
        mainId: id,
        subId: 1,
        fractionsToBuy: 1000,
        nonce: 0,
        deadline: offer.deadline + BigInt(await now()),
      };

      signature = await user1.signTypedData(domainData, offerType, params);

      const { r, s, v } = ethers.Signature.from(signature);

      await expect(
        marketplaceContract
          .connect(user1)
          .offer(
            user1.getAddress(),
            offeror.getAddress(),
            offer.offerPrice / 100n,
            id,
            1,
            1000,
            offer.deadline + BigInt(await now()),
            v,
            r,
            s
          )
      ).to.be.reverted;
    });

    it("Should revert reused signature by offeror", async function () {
      const { r, s, v } = ethers.Signature.from(signature);

      await expect(
        marketplaceContract
          .connect(offeror)
          .offer(
            user1.getAddress(),
            offeror.getAddress(),
            offer.offerPrice / 100n,
            id,
            1,
            1000,
            offer.deadline + BigInt(await now()),
            v,
            r,
            s
          )
      ).to.be.reverted;
    });

    it("Should revert expired offers", async function () {
      const expiredDeadline = BigInt(await time.latest()) - 100n;

      signature = await user1.signTypedData(domainData, offerType, params);

      const { r, s, v } = ethers.Signature.from(signature);

      await expect(
        marketplaceContract.offer(
          user1.getAddress(),
          offeror.getAddress(),
          offer.offerPrice / 100n,
          id,
          1,
          1000,
          expiredDeadline,
          v,
          r,
          s
        )
      ).to.be.reverted;
    });
  });
});
