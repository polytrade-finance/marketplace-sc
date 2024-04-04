const { ethers, upgrades } = require("hardhat");

async function main() {
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.upgradeProxy(
    "0x57c63d268C7f8B316d1A2bcE6A91C4b47BE1b942",
    Marketplace
  );
  await marketplace.waitForDeployment();

  console.log(await marketplace.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});
