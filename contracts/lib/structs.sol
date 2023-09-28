// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Listed information for each asset owner and asset id
 * @param salePrice, is the sale price of asset
 * @param minFraction, minimum fraction required for buying an asset
 */
struct ListedInfo {
    uint256 salePrice;
    uint256 minFraction;
}

struct InvoiceInfo {
    uint256 price;
    uint256 dueDate;
    uint256 rewardApr;
    uint256 fractions;
}

struct AssetInfo {
    address initialOwner;
    uint256 purchaseDate;
}

/**
 * @title storing property information
 * @param price, is the value of the property
 * @param dueDate, timestamp of which originator can not settle before it
 * @param frations, number of fractions
 */
struct PropertyInfo {
    uint256 price;
    uint256 dueDate;
    uint256 fractions;
}
