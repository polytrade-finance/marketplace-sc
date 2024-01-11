const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  // const erc721F = await ethers.getContractFactory("ERC721Token");

  // const erc721 = await erc721F.deploy(
  //   "ChetanNFT",
  //   "CNFT",
  // );
  // await erc721.waitForDeployment();

  // console.log(await erc721.getAddress());

  await hre.run("verify:verify", {
    address: "0xa03D4635F60f3A7Fa4430f130Eae6bb16750a42f",
    constructorArguments: ["ChetanNFT", "CNFT"],
  });
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});
