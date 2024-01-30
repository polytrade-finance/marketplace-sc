# Polytrade ERC6960 Marketplace

![solidity](https://img.shields.io/badge/Solidity-e6e6e6?style=for-the-badge&logo=solidity&logoColor=black) ![openzeppelin](https://img.shields.io/badge/OpenZeppelin-4E5EE4?logo=OpenZeppelin&logoColor=fff&style=for-the-badge)

This repository contains the smart contracts for ERC6960 Marketplace.

The ERC6960 Marketplace consists of two main components. The first part involves the base asset ERC6960, responsible for managing the Fractionalized creation of invoices, properties, and various types of real-world assets. This part also includes a wrapper contract that facilitates the conversion of ERC20, ERC721, and ERC1155 assets into fractionalized ERC6960, enabling them to be traded on the marketplace contract. The second part encompasses the Marketplace contract, enabling the trading the fractions of ERC6960 assets for ERC20 tokens.

## 💸 Asset Types

### Invoice Assets

The Invoice Asset contract enables the creation of invoices through Polytrade's business logic. Each invoice is associated with a fixed Annual Percentage Rate (APR) and a due date, at which point the owner can claim the invoice. Invoices can be fractionalized, and individuals can claim fractions of them. The distribution of rewards is contingent on the timing of the invoice purchase, extending until the due date.

### Property Assets

The Property Asset contract facilitates the creation of properties using third-party business logic. Each property is assigned a due date and includes relevant property information. Post the due date, the property issuer has the flexibility to settle the property at a custom price.

### Wrapped Assets

Owners of whitelisted ERC20, ERC721, and ERC1155 contracts can wrap their assets into ERC6960 and fractionalize them. This functionality facilitates the trading of these assets on the marketplace contract, enhancing the features of the tokens. The custody of wrapped assets is held by the non-upgradable and audited wrapper contract. Owners of 100% of wrapped ERC6960 tokens have the ability to unwrap their tokens back to the previous standard in a permissionless manner.

## 📈 Marketplace

### ERC6960 Marketplace 

The Marketplace serves as the primary contract for trading ERC6960 assets, be it invoices, properties, wrapped assets, or any future ERC6960 creations, in exchange for ERC20 tokens. It incorporates a specific on-chain listing mechanism for fractionalized assets. Moreover, the Marketplace enables private offers through EIP712 signatures for buyers, enhancing the feasibility of trading and providing a more seamless user experience in a secure manner.

### Fee Manager

The Fee Manager enables the admin to set fees for the initial purchase and trading of all ERC6960 assets through the Marketplace. These fees can be configured as defaults for a predefined set of assets or specified by a main ID and sub ID.

## Audits

Polytrade has enlisted the services of ImmuneBytes to perform a security audit on the Marketplace. Over the period from December 15th, 2023, to January 29th, 2024, a team of ImmuneBytes consultants conducted a thorough security review of Polytrade Marketplace. The audit did not reveal any significant flaws that could potentially compromise a smart contract, lead to the loss of funds, or cause unexpected behavior in the target system. You can access their [full report here](./audits/PolyTrade(NFT%20Marketplace)-Audit%20Report-ImmuneBytes.pdf).

## Contributing

We welcome contributions to ERC6960 Marketplace from anyone interested in enhancing the project. Contributions may include writing additional tests, improving code readability, optimizing for gas efficiency, or extending the protocol by introducing new asset type contracts or other features.

When submitting a pull request, please ensure the following:

- All tests pass.
- Code coverage remains at 100% (coverage tests must currently be written in hardhat and Js).
- Adherence to the style guide:
  - All lint checks pass.
  - Code is thoroughly commented with natspec where relevant.
- For changes to contracts:
  - Gas snapshots are provided and demonstrate an improvement (or an acceptable deficit given other improvements).
  - Reference contracts are modified correspondingly if relevant.
  - New tests are included for all new features or code paths.
- Provide a descriptive summary of the pull request.

## 📝 Contracts

```bash
Contracts
├─ Asset
│  ├─ Interface
│  │  ├─ IBaseAsset.sol
│  │  ├─ IInvoiceAsset.sol
│  │  ├─ IPropertyAsset.sol
│  │  └─ IWrappedAsset.sol
│  ├─ BaseAsset.sol
│  ├─ InvoiceAsset.sol
│  ├─ PropertyAsset.sol
│  └─ WrappedAsset.sol
├─ Marketplace
│  ├─ Interface
│  │  ├─ IMarketplace.sol
│  │  └─ IFeeManager.sol
│  ├─ Marketplace.sol
│  └─ FeeManager.sol
├─ lib
│  ├─ Counters.sol
│  ├─ errors.sol
│  └─ structs.sol
└─ Mock
   ├─ MockERC20.sol
   ├─ MockERC721.sol
   └─ MockInvoiceOwner.sol
```

## 🛠️ Install Dependencies

```bash
npm install
npx hardhat compile
npx hardhat test
```

## ⚖️ License

All files in `/contracts` are licensed under MIT as indicated in their SPDX header.
