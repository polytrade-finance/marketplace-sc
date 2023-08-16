const { ethers, upgrades } = require("hardhat");

async function main() {
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await upgrades.upgradeProxy(
    "0xc0787A0F5081173a1C9b8Ad1597377082dCE558c",
    Marketplace
  );
  await marketplace.waitForDeployment();

  console.log(`${await marketplace.getAddress()} Upgraded successfully`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  throw new Error(error);
});

// 0x72cC7f9D20DA678dfA7D72EF016d973b45f66741
// 0xdd7fded184a005ba01f9f963ff2242136cf4f3eb
// 0x4Fa8876e4ea64E86B0Ea6a29812728D763E5B1FE
