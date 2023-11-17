const { expect } = require("chai");
const { network, ethers } = require("hardhat");
const { AssetManagerAccess } = require("./data.spec");
const {
  Sand1155,
  Ens721,
  Erc20,
  Ens721Signer,
  Erc20Signer,
  Sand1155Signer,
} = require("./addresses.spec");

const { EnsTokenId, SandTokenId } = require("./data.spec");
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

const getId = async (contract, owner) => {
  const nonce = await contract.getNonce(owner);
  return BigInt(
    ethers.solidityPackedKeccak256(
      ["uint256", "address", "address", "uint256"],
      [chainId, await contract.getAddress(), owner, nonce]
    )
  );
};

describe("Wrapper Contract", function () {
  let assetContract;
  let wrapperContract;
  let user1;
  let signer20;
  let signer721;
  let signer1155;
  let erc20;
  let erc721;
  let erc1155;

  beforeEach(async () => {
    [, user1] = await ethers.getSigners();
    signer20 = await getSigner(Erc20Signer);
    signer721 = await getSigner(Ens721Signer);
    signer1155 = await getSigner(Sand1155Signer);

    erc20 = await ethers.getContractAt("IToken", Erc20);

    erc721 = await ethers.getContractAt("IERC721", Ens721);

    erc1155 = await ethers.getContractAt("IERC1155", Sand1155);

    const AssetFactory = await ethers.getContractFactory("BaseAsset");
    assetContract = await AssetFactory.deploy(
      "Polytrade Asset Collection",
      "PAC",
      "2.3",
      "https://ipfs.io/ipfs"
    );
    await assetContract.waitForDeployment();

    wrapperContract = await (
      await ethers.getContractFactory("WrappedAsset")
    ).deploy(await assetContract.getAddress());

    await wrapperContract.whitelist(Erc20, true);
    await wrapperContract.whitelist(Ens721, true);
    await wrapperContract.whitelist(Sand1155, true);
    await assetContract.grantRole(
      AssetManagerAccess,
      wrapperContract.getAddress()
    );
  });

  it("Should revert to deploy with wrong asset contract address", async function () {
    await expect(
      (
        await ethers.getContractFactory("WrappedAsset")
      ).deploy(ethers.ZeroAddress)
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

  it("Should revert on emergency unwrap erc20 by invalid caller", async function () {
    await expect(
      wrapperContract.connect(user1).emergencyUnwrapERC20(1, Ens721)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert on emergency unwrap erc721 by invalid caller", async function () {
    await expect(
      wrapperContract.connect(user1).emergencyUnwrapERC721(1, Ens721)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert on emergency unwrap erc1155 by invalid caller", async function () {
    await expect(
      wrapperContract.connect(user1).emergencyUnwrapERC1155(1, Ens721)
    ).to.be.revertedWith(
      `AccessControl: account ${(
        await user1.getAddress()
      ).toLowerCase()} is missing role ${ethers.zeroPadValue(
        ethers.toBeHex(0),
        32
      )}`
    );
  });

  it("Should revert on whitelist with invalid address", async function () {
    await expect(wrapperContract.whitelist(ethers.ZeroAddress, true)).to.be
      .reverted;
  });

  it("Should whitelist ERC20 address", async function () {
    await wrapperContract.whitelist(Erc20, true);
  });

  it("Should whitelist ERC721 address", async function () {
    await wrapperContract.whitelist(Ens721, true);
  });

  it("Should whitelist ERC1155 address", async function () {
    await wrapperContract.whitelist(Sand1155, true);
  });

  it("Should revert to wrap erc20 if there is not enough balance", async function () {
    await expect(
      wrapperContract.wrapERC20(Erc20, ethers.MaxUint256, 10000)
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert to wrap erc20 contract address is not whitelisted", async function () {
    await expect(
      wrapperContract.wrapERC20(ethers.ZeroAddress, ethers.MaxUint256, 10000)
    ).to.be.revertedWith("contract not whitelisted");
  });

  it("Should wrap erc20 token and get info", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());
    const value = ethers.parseUnits("1000", 6);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), value);
    await wrapperContract.connect(signer20).wrapERC20(Erc20, value, 10000);

    expect(
      await assetContract.subBalanceOf(signer20.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(await erc20.balanceOf(await wrapperContract.getAddress())).to.be.eq(
      value
    );

    const info = await wrapperContract.getWrappedInfo(id);
    expect(info[0]).to.be.eq(0);
    expect(info[1]).to.be.eq(10000);
    expect(info[2]).to.be.eq(value);
    expect(info[3]).to.be.eq(Erc20);

    await resetFork();
  });

  it("Should revert to wrap erc20 token twice", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());
    const value = ethers.parseUnits("1000", 6);

    await assetContract.grantRole(
      AssetManagerAccess,
      await signer20.getAddress()
    );
    await assetContract
      .connect(signer20)
      .createAsset(signer20.getAddress(), id, 1, 1);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), ethers.MaxUint256);

    await expect(
      wrapperContract.connect(signer20).wrapERC20(Erc20, value, 10000)
    ).to.be.revertedWith("Asset already created");

    await resetFork();
  });

  it("Should revert to unwrap erc20 token without complete ownership", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());
    const value = ethers.parseUnits("1000", 6);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), ethers.MaxUint256);
    await wrapperContract.connect(signer20).wrapERC20(Erc20, value, 10000);
    await assetContract
      .connect(signer20)
      .transferFrom(signer20.getAddress(), user1.getAddress(), id, 1, 1);

    await expect(
      wrapperContract.connect(signer20).unwrapERC20(id)
    ).to.be.revertedWith("Partial ownership");

    await resetFork();
  });

  it("Should unwrap erc20 token", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());
    const value = ethers.parseUnits("1000", 6);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), ethers.MaxUint256);
    await wrapperContract.connect(signer20).wrapERC20(Erc20, value, 10000);

    const beforeUnwrapBalance = await erc20.balanceOf(
      await signer20.getAddress()
    );
    await wrapperContract.connect(signer20).unwrapERC20(id);
    const afterUnwrapBalance = await erc20.balanceOf(
      await signer20.getAddress()
    );

    expect(await assetContract.totalSubSupply(id, 1)).to.be.eq(0);

    expect(afterUnwrapBalance - beforeUnwrapBalance).to.be.eq(value);

    await resetFork();
  });

  it("Should emergency unwrap erc20 token without complete ownership", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());
    const value = ethers.parseUnits("1000", 6);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), ethers.MaxUint256);
    await wrapperContract.connect(signer20).wrapERC20(Erc20, value, 10000);
    await assetContract
      .connect(signer20)
      .transferFrom(signer20.getAddress(), user1.getAddress(), id, 1, 9999);

    const beforeUnwrapBalance = await erc20.balanceOf(
      await signer20.getAddress()
    );
    await wrapperContract.emergencyUnwrapERC20(id, await signer20.getAddress());
    const afterUnwrapBalance = await erc20.balanceOf(
      await signer20.getAddress()
    );

    expect(
      await assetContract.subBalanceOf(await signer20.getAddress(), id, 1)
    ).to.be.eq(0);

    expect(afterUnwrapBalance - beforeUnwrapBalance).to.be.eq(value);

    await resetFork();
  });

  it("Should revert batch wrap erc20 token without array parity", async function () {
    const value = ethers.parseUnits("1000", 6);

    await expect(
      wrapperContract
        .connect(signer20)
        .batchWrapERC20([Erc20], [value], [10000, 1])
    ).to.be.revertedWith("No array parity");
  });

  it("Should batch wrap erc20 token", async function () {
    const id = await getId(wrapperContract, await signer20.getAddress());

    const value = ethers.parseUnits("1000", 6);

    await erc20
      .connect(signer20)
      .approve(await wrapperContract.getAddress(), ethers.MaxUint256);
    await wrapperContract
      .connect(signer20)
      .batchWrapERC20([Erc20], [value], [10000]);

    expect(
      await assetContract.subBalanceOf(signer20.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(await erc20.balanceOf(await wrapperContract.getAddress())).to.be.eq(
      value
    );
  });

  it("Should revert to wrap erc721 if not owner", async function () {
    await expect(
      wrapperContract.wrapERC721(Ens721, EnsTokenId, 10000)
    ).to.be.revertedWith("You are not the owner");
  });

  it("Should revert to wrap erc721 contract address is not whitelisted", async function () {
    await expect(
      wrapperContract.wrapERC721(ethers.ZeroAddress, EnsTokenId, 10000)
    ).to.be.revertedWith("contract not whitelisted");
  });

  it("Should revert to wrap erc721 contract address is wrong", async function () {
    await expect(wrapperContract.wrapERC721(Erc20, EnsTokenId, 10000)).to.be
      .reverted;
  });

  it("Should wrap erc721 token and get info", async function () {
    const id = await getId(wrapperContract, await signer721.getAddress());

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
    const id = await getId(wrapperContract, await signer721.getAddress());
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
    const id = await getId(wrapperContract, await signer721.getAddress());

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
    const id = await getId(wrapperContract, await signer721.getAddress());

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

  it("Should emergency unwrap erc721 token without complete ownership", async function () {
    const id = await getId(wrapperContract, await signer721.getAddress());

    await erc721
      .connect(signer721)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer721)
      .wrapERC721(Ens721, EnsTokenId, 10000);
    await assetContract
      .connect(signer721)
      .transferFrom(signer721.getAddress(), user1.getAddress(), id, 1, 9999);

    await wrapperContract.emergencyUnwrapERC721(
      id,
      await signer721.getAddress()
    );

    expect(
      await assetContract.subBalanceOf(await signer721.getAddress(), id, 1)
    ).to.be.eq(0);

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
    const id = await getId(wrapperContract, await signer721.getAddress());

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
      wrapperContract.wrapERC1155(Sand1155, SandTokenId, 1, 10000)
    ).to.be.revertedWith("Not enough balance");
  });

  it("Should revert to wrap erc1155 contract address is not whitelisted", async function () {
    await expect(
      wrapperContract.wrapERC1155(ethers.ZeroAddress, SandTokenId, 1, 10000)
    ).to.be.revertedWith("contract not whitelisted");
  });

  it("Should revert to wrap erc1155 contract address is wrong", async function () {
    await expect(wrapperContract.wrapERC1155(Ens721, SandTokenId, 1, 10000)).to
      .be.reverted;
  });

  it("Should wrap erc1155 token and get info", async function () {
    const id = await getId(wrapperContract, await signer1155.getAddress());

    const balance = await erc1155.balanceOf(
      signer1155.getAddress(),
      SandTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Sand1155, SandTokenId, balance, 10000);

    expect(
      await assetContract.subBalanceOf(signer1155.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(
      await erc1155.balanceOf(wrapperContract.getAddress(), SandTokenId)
    ).to.be.eq(balance);

    const info = await wrapperContract.getWrappedInfo(id);
    expect(info[0]).to.be.eq(SandTokenId);
    expect(info[1]).to.be.eq(10000);
    expect(info[2]).to.be.eq(balance);
    expect(info[3]).to.be.eq(Sand1155);

    await resetFork();
  });

  it("Should revert to wrap erc1155 token twice", async function () {
    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);

    const id = await getId(wrapperContract, await signer1155.getAddress());

    await assetContract.grantRole(
      AssetManagerAccess,
      await signer1155.getAddress()
    );
    await assetContract
      .connect(signer1155)
      .createAsset(signer1155.getAddress(), id, 1, 1);

    await expect(
      wrapperContract
        .connect(signer1155)
        .wrapERC1155(Sand1155, SandTokenId, 1, 10000)
    ).to.be.revertedWith("Asset already created");

    await resetFork();
  });

  it("Should revert to unwrap erc1155 token without complete ownership", async function () {
    const id = await getId(wrapperContract, await signer1155.getAddress());

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Sand1155, SandTokenId, 1, 10000);
    await assetContract
      .connect(signer1155)
      .transferFrom(signer1155.getAddress(), user1.getAddress(), id, 1, 1);

    await expect(
      wrapperContract.connect(signer1155).unwrapERC1155(id)
    ).to.be.revertedWith("Partial ownership");

    await resetFork();
  });

  it("Should unwrap erc1155 token", async function () {
    const id = await getId(wrapperContract, await signer1155.getAddress());

    const balance = await erc1155.balanceOf(
      await signer1155.getAddress(),
      SandTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Sand1155, SandTokenId, 1, 10000);

    await wrapperContract.connect(signer1155).unwrapERC1155(id);

    expect(await assetContract.totalSubSupply(id, 1)).to.be.eq(0);

    expect(
      await erc1155.balanceOf(await signer1155.getAddress(), SandTokenId)
    ).to.be.eq(balance);

    await resetFork();
  });

  it("Should emergency unwrap erc1155 token without complete ownership", async function () {
    const id = await getId(wrapperContract, await signer1155.getAddress());

    const balance = await erc1155.balanceOf(
      await signer1155.getAddress(),
      SandTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .wrapERC1155(Sand1155, SandTokenId, 1, 10000);
    await assetContract
      .connect(signer1155)
      .transferFrom(signer1155.getAddress(), user1.getAddress(), id, 1, 9999);

    await wrapperContract.emergencyUnwrapERC1155(
      id,
      await signer1155.getAddress()
    );

    expect(
      await assetContract.subBalanceOf(await signer1155.getAddress(), id, 1)
    ).to.be.eq(0);

    expect(
      await erc1155.balanceOf(await signer1155.getAddress(), SandTokenId)
    ).to.be.eq(balance);

    await resetFork();
  });

  it("Should revert batch wrap erc1155 token without array parity", async function () {
    await expect(
      wrapperContract
        .connect(signer1155)
        .batchWrapERC1155([Sand1155], [SandTokenId], [1], [10000, 1])
    ).to.be.revertedWith("No array parity");
  });

  it("Should batch wrap erc1155 token", async function () {
    const id = await getId(wrapperContract, await signer1155.getAddress());

    const balance = await erc1155.balanceOf(
      await signer1155.getAddress(),
      SandTokenId
    );

    await erc1155
      .connect(signer1155)
      .setApprovalForAll(await wrapperContract.getAddress(), true);
    await wrapperContract
      .connect(signer1155)
      .batchWrapERC1155([Sand1155], [SandTokenId], [balance], [10000]);

    expect(
      await assetContract.subBalanceOf(signer1155.getAddress(), id, 1)
    ).to.be.eq(10000);

    expect(
      await erc1155.balanceOf(wrapperContract.getAddress(), SandTokenId)
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
          SandTokenId,
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
          [SandTokenId],
          [1],
          "0x"
        )
    ).to.be.reverted;
    await resetFork();
  });

  it("Should revert unwrap20 with invalid id", async function () {
    await expect(
      wrapperContract.connect(signer20).unwrapERC20(1)
    ).to.be.revertedWith("Wrong asset id");
  });

  it("Should revert unwrap721 with invalid id", async function () {
    await expect(
      wrapperContract.connect(signer721).unwrapERC721(1)
    ).to.be.revertedWith("Wrong asset id");
  });

  it("Should revert unwrap1155 with invalid id", async function () {
    await expect(
      wrapperContract.connect(signer1155).unwrapERC1155(1)
    ).to.be.revertedWith("Wrong asset id");
  });
});
