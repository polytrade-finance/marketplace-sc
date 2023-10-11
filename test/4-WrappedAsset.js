const { expect } = require("chai");
const { network, ethers, upgrades } = require("hardhat");
const { AssetManagerAccess } = require("./data");
const {
  Enjin1155,
  Ens721,
  Ens721Signer,
  EnsTokenId,
  EnjinTokenId,
  Enjin1155Signer,
} = require("./addresses");
const chainId = network.config.chainId;

const getSigner = async (address) => {
  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [address],
  });
  return await ethers.provider.getSigner(address);
};

const resetFork = async () => {
  await network.provider.request({
    method: "hardhat_reset",
    params: [
      {
        forking: {
          jsonRpcUrl: "https://rpc.ankr.com/eth",
          blockNumber: 18314577,
        },
      },
    ],
  });
};

const get721Id = async (contract, tokenId) => {
  return BigInt(
    ethers.solidityPackedKeccak256(
      ["uint256", "address", "uint256"],
      [chainId, await contract.getAddress(), tokenId]
    )
  );
};

const get1155Id = async (signer, contract, tokenId) => {
  return BigInt(
    ethers.solidityPackedKeccak256(
      ["uint256", "address", "address", "uint256"],
      [chainId, await signer.getAddress(), await contract.getAddress(), tokenId]
    )
  );
};

describe("Wrapper Contract", function () {
  let assetContract;
  let wrapperContract;
  let user1;
  let signer721;
  let signer1155;
  let erc721;
  let erc1155;

  beforeEach(async () => {
    [, user1] = await ethers.getSigners();
    signer721 = await getSigner(Ens721Signer);
    signer1155 = await getSigner(Enjin1155Signer);

    erc721 = await ethers.getContractAt("IERC721", Ens721);

    erc1155 = await ethers.getContractAt("IERC1155", Enjin1155);

    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PAC",
      "2.3",
      "https://ipfs.io/ipfs"
    );
    await assetContract.waitForDeployment();

    wrapperContract = await upgrades.deployProxy(
      await ethers.getContractFactory("WrappedAsset"),
      [await assetContract.getAddress()]
    );

    await wrapperContract.whitelist(Ens721, true);
    await wrapperContract.whitelist(Enjin1155, true);
    await assetContract.grantRole(
      AssetManagerAccess,
      wrapperContract.getAddress()
    );
  });

  it("Should revert to initialize again", async function () {
    await expect(wrapperContract.initialize(assetContract.getAddress())).to.be
      .reverted;
  });

  it("Should revert to initialize with wrong asset contract address", async function () {
    await expect(
      upgrades.deployProxy(await ethers.getContractFactory("WrappedAsset"), [
        ethers.ZeroAddress,
      ])
    ).to.be.reverted;
  });

  it("Should revert on whitelist by invalid caller", async function () {
    await expect(
      wrapperContract.connect(user1).whitelist(Ens721, true)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert on whitelisting wrong address", async function () {
    await expect(wrapperContract.whitelist(await user1.getAddress(), true)).to
      .be.reverted;
  });

  it("Should whitelist ERC721 address", async function () {
    await wrapperContract.whitelist(Ens721, true);
  });

  it("Should whitelist ERC1155 address", async function () {
    await wrapperContract.whitelist(Enjin1155, true);
  });

  it("Should revert to wrap erc721 if not owner", async function () {
    await expect(
      wrapperContract.wrapERC721(Ens721, EnsTokenId, 10000)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should revert to wrap erc721 contract address is wrong", async function () {
    await expect(
      wrapperContract.wrapERC721(ethers.ZeroAddress, EnsTokenId, 10000)
    ).to.be.revertedWith("contract not whitelisted");
  });

  it("Should wrap erc721 token and get info", async function () {
    const id = await get721Id(erc721, EnsTokenId);

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer721)
      .wrapERC721(Ens721, EnsTokenId, 10000);

    expect(
      await assetContract.subBalanceOf(signer721.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(await erc721.ownerOf(EnsTokenId)).to.be.eq(
      await wrapperContract.getAddress()
    );

    const info = await wrapperContract.getWrappedInfo(id);
    expect(info[0]).to.be.eq(EnsTokenId);
    expect(info[1]).to.be.eq(10000);
    expect(info[2]).to.be.eq(1);
    expect(info[3]).to.be.eq(Ens721);

    await resetFork();
  });

  it("Should revert to wrap erc721 token twice", async function () {
    const id = await get721Id(erc721, EnsTokenId);
    await assetContract.grantRole(
      AssetManagerAccess,
      await signer721.getAddress()
    );
    await assetContract
      .connect(signer721)
      .createAsset(signer721.getAddress(), id, 1, 1);

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);

    await expect(
      wrapperContract.connect(signer721).wrapERC721(Ens721, EnsTokenId, 10000)
    ).to.be.revertedWith("Asset already created");

    await resetFork();
  });

  it("Should revert to unwrap erc721 token without complete ownership", async function () {
    const id = await get721Id(erc721, EnsTokenId);

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer721)
      .wrapERC721(Ens721, EnsTokenId, 10000);
    await assetContract
      .connect(signer721)
      .transferFrom(signer721.getAddress(), user1.getAddress(), id, 1, 1);

    await expect(
      wrapperContract.connect(signer721).unwrapERC721(id)
    ).to.be.revertedWith("Partial ownership");

    await resetFork();
  });

  it("Should unwrap erc721 token", async function () {
    const id = await get721Id(erc721, EnsTokenId);

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer721)
      .wrapERC721(Ens721, EnsTokenId, 10000);

    await wrapperContract.connect(signer721).unwrapERC721(id);

    expect(await assetContract.totalSubSupply(id, 1)).to.be.eq(0);

    expect(await erc721.ownerOf(EnsTokenId)).to.be.eq(
      await signer721.getAddress()
    );

    await resetFork();
  });

  it("Should revert batch wrap erc721 token without array parity", async function () {
    await expect(
      wrapperContract
        .connect(signer721)
        .batchWrapERC721([Ens721], [EnsTokenId], [10000, 1])
    ).to.be.revertedWith("No array parity");
  });

  it("Should batch wrap erc721 token", async function () {
    const id = await get721Id(erc721, EnsTokenId);

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer721)
      .batchWrapERC721([Ens721], [EnsTokenId], [10000]);

    expect(
      await assetContract.subBalanceOf(signer721.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(await erc721.ownerOf(EnsTokenId)).to.be.eq(
      await wrapperContract.getAddress()
    );
  });

  it("Should revert to wrap erc1155 if not owner", async function () {
    await expect(
      wrapperContract.wrapERC1155(Enjin1155, EnjinTokenId, 10000)
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert to wrap erc1155 contract address is wrong", async function () {
    await expect(
      wrapperContract.wrapERC1155(ethers.ZeroAddress, EnjinTokenId, 10000)
    ).to.be.revertedWith("contract not whitelisted");
  });

  it("Should wrap erc1155 token and get info", async function () {
    const id = await get1155Id(signer1155, erc1155, EnjinTokenId);

    const balance = await erc1155.balanceOf(
      signer1155.getAddress(),
      EnjinTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Enjin1155, EnjinTokenId, 10000);

    expect(
      await assetContract.subBalanceOf(signer1155.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(
      await erc1155.balanceOf(wrapperContract.getAddress(), EnjinTokenId)
    ).to.be.eq(balance);

    const info = await wrapperContract.getWrappedInfo(id);
    expect(info[0]).to.be.eq(EnjinTokenId);
    expect(info[1]).to.be.eq(10000);
    expect(info[2]).to.be.eq(balance);
    expect(info[3]).to.be.eq(Enjin1155);

    await resetFork();
  });

  it("Should revert to wrap erc1155 token twice", async function () {
    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await erc1155
      .connect(signer1155)
      .safeTransferFrom(
        await signer1155.getAddress(),
        await user1.getAddress(),
        EnjinTokenId,
        1,
        "0x"
      );
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Enjin1155, EnjinTokenId, 10000);

    await erc1155
      .connect(user1)
      .safeTransferFrom(
        await user1.getAddress(),
        await signer1155.getAddress(),
        EnjinTokenId,
        1,
        "0x"
      );

    await expect(
      wrapperContract
        .connect(signer1155)
        .wrapERC1155(Enjin1155, EnjinTokenId, 10000)
    ).to.be.revertedWith("Asset already created");

    await resetFork();
  });

  it("Should revert to unwrap erc1155 token without complete ownership", async function () {
    const id = await get1155Id(signer1155, erc1155, EnjinTokenId);

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Enjin1155, EnjinTokenId, 10000);
    await assetContract
      .connect(signer1155)
      .transferFrom(signer1155.getAddress(), user1.getAddress(), id, 1, 1);

    await expect(
      wrapperContract.connect(signer1155).unwrapERC1155(id)
    ).to.be.revertedWith("Partial ownership");

    await resetFork();
  });

  it("Should unwrap erc1155 token", async function () {
    const id = await get1155Id(signer1155, erc1155, EnjinTokenId);

    const balance = await erc1155.balanceOf(
      await signer1155.getAddress(),
      EnjinTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Enjin1155, EnjinTokenId, 10000);

    await wrapperContract.connect(signer1155).unwrapERC1155(id);

    expect(await assetContract.totalSubSupply(id, 1)).to.be.eq(0);

    expect(
      await erc1155.balanceOf(await signer1155.getAddress(), EnjinTokenId)
    ).to.be.eq(balance);

    await resetFork();
  });

  it("Should revert batch wrap erc1155 token without array parity", async function () {
    await expect(
      wrapperContract
        .connect(signer1155)
        .batchWrapERC1155([Enjin1155], [EnjinTokenId], [10000, 1])
    ).to.be.revertedWith("No array parity");
  });

  it("Should batch wrap erc1155 token", async function () {
    const id = await get1155Id(signer1155, erc1155, EnjinTokenId);

    const balance = await erc1155.balanceOf(
      await signer1155.getAddress(),
      EnjinTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .batchWrapERC1155([Enjin1155], [EnjinTokenId], [10000]);

    expect(
      await assetContract.subBalanceOf(signer1155.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(
      await erc1155.balanceOf(wrapperContract.getAddress(), EnjinTokenId)
    ).to.be.eq(balance);
  });

  it("Should revert to transfer erc721 token directly to contract", async function () {
    await expect(
      erc721
        .connect(signer721)
        .safeTransferFrom(
          await signer721.getAddress(),
          await wrapperContract.getAddress(),
          EnsTokenId
        )
    ).to.be.reverted;
    await resetFork();
  });

  it("Should revert to transfer erc1155 token directly to contract", async function () {
    await expect(
      erc1155
        .connect(signer1155)
        .safeTransferFrom(
          await signer1155.getAddress(),
          await wrapperContract.getAddress(),
          EnjinTokenId,
          1,
          "0x"
        )
    ).to.be.reverted;
    await resetFork();
  });

  it("Should revert to batch transfer erc1155 token directly to contract", async function () {
    await expect(
      erc1155
        .connect(signer1155)
        .safeBatchTransferFrom(
          await signer1155.getAddress(),
          await wrapperContract.getAddress(),
          [EnjinTokenId],
          [1],
          "0x"
        )
    ).to.be.reverted;
    await resetFork();
  });

  it("Should revert unwrap invalid id", async function () {
    await expect(
      wrapperContract.connect(signer721).unwrapERC721(1)
    ).to.be.revertedWith("Wrong asset id");
  });
});
