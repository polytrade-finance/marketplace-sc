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
 * @param value, is the value of the property
 * @param size, is the size of the property is sq2
 * @param rooms, is the number of the rooms
 * @param bathrooms, is the number of the bathrooms
 * @param constructionDate, is the date of property construction
 * @param country, is the location country
 * @param city, is the location city
 * @param location, is the google map location
 */
struct PropertyInfo {
    uint256 price;
    uint256 dueDate;
    uint256 fractions;
}
