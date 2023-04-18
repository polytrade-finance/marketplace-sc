const { ethers } = require("hardhat");

const invoice1 = {
  initialMainMetadata: {
    lateFeePercentage: 10,
    gracePeriod: 10,
    dueDate: Number(new Date("2022-11-12").getTime() / 1000),
    invoiceDate: Number(new Date("2022-10-10").getTime() / 1000),
    fundsAdvancedDate: Number(new Date("2022-10-13").getTime() / 1000),
    invoiceAmount: ethers.utils.parseEther("10000"),
  },
  initialSubMetadata: {
    factoringFeePercentage: 10,
    discountFeePercentage: 10,
    bankChargesFeeAmount: 10,
    additionalFeeAmount: 10,
    advanceFeePercentage: 1000, // %10
  },
};

module.exports = {
  invoice1,
};
