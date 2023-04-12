const { ethers } = require("hardhat");

const invoice1 = [
  10, //  factoringFeePercentage,
  10, // discountFeePercentage,
  10, // lateFeePercentage,
  10, //  bankChargesFeeAmount,
  10, //  additionalFeeAmount,
  10, //  advanceFeeAmount,
  10, // gracePeriod,
  Number(new Date("2022-11-12").getTime() / 1000), // dueDate,
  Number(new Date("2022-10-10").getTime() / 1000), //  invoiceDate,
  Number(new Date("2022-10-13").getTime() / 1000), // fundsAdvancedDate,
  ethers.utils.parseEther("10000"), // invoiceAmount,
];

module.exports = {
  invoice1,
};
