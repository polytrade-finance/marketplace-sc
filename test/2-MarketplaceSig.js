const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const {
  asset,
  MarketplaceAccess,
  offer,
  AssetManagerAccess,
  OriginatorAccess,
} = require("./data");
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
  let chainId;
  let domainSeparator;
  let signature;
  let params;
  let domainData;
  let offerType;

  beforeEach(async () => {
    [deployer, user1, offeror, treasuryWallet, feeWallet] =
      await ethers.getSigners();

    name = "Polytrade";
    version = "2.2";
    chainId = 31337;
    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PIC",
      "2.2",
      "https://ipfs.io/ipfs"
    );

    await assetContract.waitForDeployment();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
    ).deploy("USD Dollar", "USDC", 18, offeror.getAddress(), 200000);

    marketplaceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("Marketplace"),
      [
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        await feeWallet.getAddress(),
      ]
    );

    invoiceContract = await upgrades.deployProxy(
      await ethers.getContractFactory("InvoiceAsset"),
      [
        await assetContract.getAddress(),
        await stableTokenContract.getAddress(),
        await treasuryWallet.getAddress(),
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

    await invoiceContract.grantRole(OriginatorAccess, deployer.getAddress());

    await invoiceContract.createInvoice(user1.getAddress(), 1, 1, asset);

    await marketplaceContract.connect(user1).list(1, 1, asset.price, 1000);

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
      CounterOffer: [
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
      expect(await marketplaceContract.nonces(user1.getAddress())).to.be.equal(
        "0"
      );
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
        offerPrice: offer.offerPrice,
        mainId: 1,
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

      await marketplaceContract
        .connect(offeror)
        .counterOffer(
          user1.getAddress(),
          offeror.getAddress(),
          offer.offerPrice,
          1,
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

      expect(balanceBeforeBuy - balanceAfterBuy).to.be.equal(
        offer.offerPrice / 10n
      );
      expect(await marketplaceContract.nonces(user1.getAddress())).to.be.equal(
        "1"
      );
      expect(
        await stableTokenContract.balanceOf(user1.getAddress())
      ).to.be.equal(offer.offerPrice / 10n);
    });

    it("Should revert if sender is not offeror", async function () {
      params = {
        owner: await user1.getAddress(),
        offeror: await offeror.getAddress(),
        offerPrice: offer.offerPrice,
        mainId: 1,
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
          .counterOffer(
            user1.getAddress(),
            offeror.getAddress(),
            offer.offerPrice,
            1,
            1,
            1000,
            offer.deadline + BigInt(await now()),
            v,
            r,
            s
          )
      ).to.be.revertedWith("You are not the offeror");
    });

    it("Should revert reused signature by offeror", async function () {
      const { r, s, v } = ethers.Signature.from(signature);

      await expect(
        marketplaceContract
          .connect(offeror)
          .counterOffer(
            user1.getAddress(),
            offeror.getAddress(),
            offer.offerPrice,
            1,
            1,
            1000,
            offer.deadline + BigInt(await now()),
            v,
            r,
            s
          )
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert expired offers", async function () {
      const expiredDeadline = BigInt(await time.latest()) - 100n;

      signature = await user1.signTypedData(domainData, offerType, params);

      const { r, s, v } = ethers.Signature.from(signature);

      await expect(
        marketplaceContract.counterOffer(
          user1.getAddress(),
          offeror.getAddress(),
          offer.offerPrice,
          1,
          1,
          1000,
          expiredDeadline,
          v,
          r,
          s
        )
      ).to.be.revertedWith("Offer expired");
    });
  });
});
