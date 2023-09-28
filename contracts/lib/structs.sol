// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Listed information for each asset owner and asset id
 * @param minFraction, minimum fraction required for buying an asset
 */
struct ListedInfo {
    uint256 salePrice;
    uint256 minFraction;
}

/**
 * @title storing invoice information
 * @param price, is the initial owner of asset
 * @param dueDate, timestamp of which originator can not settle before it
 * @param rewardApr, reward apr of invoice usied in reward calculations
 * @param fractions, number of fractions
 */
struct InvoiceInfo {
    uint256 price;
    uint256 dueDate;
    uint256 rewardApr;
    uint256 fractions;
}

/**
 * @title storing asset information
 * @param initialOwner, is the initial owner of asset
 * @param purchaseDate, date that first time a fraction of asset is purchased
 */
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
