const { expect } = require("chai");
const { ethers } = require("hardhat");
const { splitSignature } = require("ethers/lib/utils");
const { asset, MarketplaceAccess, offer } = require("./data");
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
  let user1;
  let offeror;
  let treasuryWallet;
  let feeWallet;
  let name;
  let version;
  let chainId;
  let domainSeparator;
  let signature;
  let params;
  let domainData;
  let offerType;

  beforeEach(async () => {
    [, user1, offeror, treasuryWallet, feeWallet] = await ethers.getSigners();

    name = "Polytrade";
    version = "2.1";
    chainId = 31337;
    const AssetFactory = await ethers.getContractFactory("Asset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PIC",
      "https://ipfs.io/ipfs"
    );

    await assetContract.deployed();

    stableTokenContract = await (
      await ethers.getContractFactory("ERC20Token")
    ).deploy("USD Dollar", "USDC", 18, offeror.address, 200000);

    marketplaceContract = await (
      await ethers.getContractFactory("Marketplace")
    ).deploy(
      assetContract.address,
      stableTokenContract.address,
      treasuryWallet.address,
      feeWallet.address
    );

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
      .connect(offeror)
      .approve(marketplaceContract.address, 10 * asset.assetPrice);

    domainSeparator = await marketplaceContract.DOMAIN_SEPARATOR();

    domainData = {
      name,
      version,
      chainId,
      verifyingContract: marketplaceContract.address,
    };

    offerType = {
      CounterOffer: [
        { name: "owner", type: "address" },
        { name: "offeror", type: "address" },
        { name: "collection", type: "address" },
        { name: "offerPrice", type: "uint256" },
        { name: "assetId", type: "uint256" },
        { name: "nonce", type: "uint256" },
        { name: "deadline", type: "uint256" },
      ],
    };
  });

  describe("Counter Offer", function () {
    it("Should return 0 for initial nonce", async function () {
      expect(await marketplaceContract.nonces(user1.address)).to.be.equal("0");
    });

    it("Should return correct domain separator", async function () {
      expect(domainSeparator).to.equal(
        await domainSeparatorCal(
          name,
          version,
          31337,
          marketplaceContract.address
        )
      );
    });

    it("Should buy asset with owner signed offer", async function () {
      params = {
        owner: user1.address,
        offeror: offeror.address,
        collection: assetContract.address,
        offerPrice: offer.offerPrice,
        assetId: 1,
        nonce: 0,
        deadline: offer.deadline + (await now()),
      };

      signature = await user1._signTypedData(domainData, offerType, params);
      // Validate Signature Offchain
      const hash = calculateOfferHash(params);

      validateRecoveredAddress(user1.address, domainSeparator, hash, signature);

      const { r, s, v } = splitSignature(signature);

      const balanceBeforeBuy = await stableTokenContract.balanceOf(
        offeror.address
      );

      await marketplaceContract
        .connect(offeror)
        .counterOffer(
          user1.address,
          offeror.address,
          assetContract.address,
          offer.offerPrice,
          1,
          offer.deadline + (await now()),
          v,
          r,
          s
        );

      const balanceAfterBuy = await stableTokenContract.balanceOf(
        offeror.address
      );

      expect(balanceBeforeBuy.sub(balanceAfterBuy)).to.be.equal(
        offer.offerPrice
      );
      expect(await marketplaceContract.nonces(user1.address)).to.be.equal("1");
      expect(
        await stableTokenContract.balanceOf(treasuryWallet.address)
      ).to.be.equal(offer.offerPrice);
    });

    it("Should revert if signer is not asset owner", async function () {
      params = {
        owner: offeror.address,
        offeror: user1.address,
        collection: assetContract.address,
        offerPrice: offer.offerPrice,
        assetId: 1,
        nonce: 0,
        deadline: offer.deadline + (await now()),
      };

      signature = await offeror._signTypedData(domainData, offerType, params);

      const { r, s, v } = splitSignature(signature);

      await expect(
        marketplaceContract
          .connect(offeror)
          .counterOffer(
            offeror.address,
            user1.address,
            assetContract.address,
            offer.offerPrice,
            1,
            offer.deadline + (await now()),
            v,
            r,
            s
          )
      ).to.be.revertedWith("Signer is not the owner");
    });

    it("Should revert if sender is not offeror", async function () {
      params = {
        owner: user1.address,
        offeror: offeror.address,
        collection: assetContract.address,
        offerPrice: offer.offerPrice,
        assetId: 1,
        nonce: 0,
        deadline: offer.deadline + (await now()),
      };

      signature = await user1._signTypedData(domainData, offerType, params);

      const { r, s, v } = splitSignature(signature);

      await expect(
        marketplaceContract
          .connect(user1)
          .counterOffer(
            user1.address,
            offeror.address,
            assetContract.address,
            offer.offerPrice,
            1,
            offer.deadline + (await now()),
            v,
            r,
            s
          )
      ).to.be.revertedWith("You are not the offeror");
    });

    it("Should revert reused signature by offeror", async function () {
      const { r, s, v } = splitSignature(signature);

      await expect(
        marketplaceContract
          .connect(offeror)
          .counterOffer(
            user1.address,
            offeror.address,
            assetContract.address,
            offer.offerPrice,
            1,
            offer.deadline + (await now()),
            v,
            r,
            s
          )
      ).to.be.revertedWith("Invalid signature");
    });

    it("Should revert expired offers", async function () {
      const expiredDeadline = (await time.latest()) - 100;

      signature = await user1._signTypedData(domainData, offerType, params);

      const { r, s, v } = splitSignature(signature);

      await expect(
        marketplaceContract.counterOffer(
          user1.address,
          offeror.address,
          assetContract.address,
          offer.offerPrice,
          1,
          expiredDeadline,
          v,
          r,
          s
        )
      ).to.be.revertedWith("Offer expired");
    });
  });
});
