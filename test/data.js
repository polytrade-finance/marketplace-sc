const { ethers } = require("hardhat");

const DECIMALS = {
  TWO: 2,
  SIX: 6,
  EIGHTEEN: 18,
};

const invoice1 = {
  initialMainMetadata: {
    lateFeePercentage: ethers.utils.parseUnits("10", DECIMALS.TWO),
    gracePeriod: 10, // in days
    dueDate: Number(new Date("2022-11-12").getTime() / 1000), // in seconds
    invoiceDate: Number(new Date("2022-10-10").getTime() / 1000), // in seconds
    fundsAdvancedDate: Number(new Date("2022-10-13").getTime() / 1000), // in seconds
    invoiceAmount: ethers.utils.parseUnits("10000", DECIMALS.SIX),
  },
  initialSubMetadata: {
    factoringFeePercentage: ethers.utils.parseUnits("10", DECIMALS.TWO),
    discountFeePercentage: ethers.utils.parseUnits("10", DECIMALS.TWO),
    bankChargesFeeAmount: ethers.utils.parseUnits("10", DECIMALS.SIX),
    additionalFeeAmount: ethers.utils.parseUnits("10", DECIMALS.SIX),
    advanceFeePercentage: ethers.utils.parseUnits("90", DECIMALS.TWO), // %90
  },
};

module.exports = {
  invoice1,
  DECIMALS,
};
