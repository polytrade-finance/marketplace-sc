require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("hardhat-contract-sizer");
require("dotenv").config();

const {
  TESTNET_PRIVATE_KEY,
  MAINNET_PRIVATE_KEY,
  TESTNET_ARCHIVAL_RPC,
  MAINNET_ARCHIVAL_RPC,
  MASTERCARD_PRIVATE_KEY,
  MASTERCARD_ARCHIVAL_RPC,
} = process.env;

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10000,
        details: {
          yul: true,
        },
      },
    },
  },
  networks: {
    mumbai: {
      url: `${TESTNET_ARCHIVAL_RPC}`,
      accounts: [
        `${
          TESTNET_PRIVATE_KEY ||
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        }`,
      ],
    },
    polygon: {
      url: `${MAINNET_ARCHIVAL_RPC}`,
      accounts: [
        `${
          MAINNET_PRIVATE_KEY ||
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        }`,
      ],
    },
    mastercard: {
      url: `${MASTERCARD_ARCHIVAL_RPC}`,
      chainId: 1223532587,
      accounts: [
        `${
          MASTERCARD_PRIVATE_KEY ||
          "0x0000000000000000000000000000000000000000000000000000000000000000"
        }`,
      ],
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
};
