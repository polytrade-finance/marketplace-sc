import { ethers } from "hardhat";
import { expect } from "chai";

describe("MyHardhatApplication", function () {
  let myHardhatApplication;

  beforeEach(async () => {
    const MyHardhatApplication = await ethers.getContractFactory(
      "MyHardhatApplication"
    );
    myHardhatApplication = await MyHardhatApplication.deploy();
    await myHardhatApplication.deployed();
  });

  it("should do something", async function () {
    // TODO: Write your test case here
  });
});
