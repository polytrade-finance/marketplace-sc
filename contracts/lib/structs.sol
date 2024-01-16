// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IToken } from "contracts/Token/interface/IToken.sol";

/**
 * @title Listed information for each asset owner and asset id
 * @param salePrice, sale price for the asset
 * @param listedFractions, number of fractions listed by owner
 * @param minFraction, minimum fraction required for buying an asset
 * @param token, address of token to receive salePrice
 */
struct ListedInfo {
    uint256 salePrice;
    uint256 listedFractions;
    uint256 minFraction;
    IToken token;
}

/**
 * @title storing invoice information
 * @param price, is the settlement price of invoice
 * @param dueDate, timestamp of which originator can not settle before it
 * @param rewardApr, apr of invoice used in reward calculations
 * @param fractions, number of fractions
 * @param settlementToken, the token which settlement set for by originator
 */
struct InvoiceInfo {
    uint256 price;
    uint256 dueDate;
    uint256 rewardApr;
    uint256 fractions;
    IToken settlementToken;
}

/**
 * @title storing wrapped asset information
 * @param tokenId, is the identifier of asset
 * @param fractions, number of fractions of asset
 * @param balance, balance of asset
 * @param contractAddress, asset contract address
 */
struct WrappedInfo {
    uint256 tokenId;
    uint256 fractions;
    uint256 balance;
    address contractAddress;
}

/**
 * @title storing asset information
 * @param initialOwner, is the initial owner of asset
 * @param purchaseDate, date that first time a fraction of asset is purchased
 */
struct AssetInfo {
    address initialOwner;
}

/**
 * @title storing property information
 * @param price, is the value of the property
 * @param dueDate, timestamp of which originator can not settle before it
 * @param frations, number of fractions
 * @param settlementToken, the token which settlement set for by originator
 */
struct PropertyInfo {
    uint256 price;
    uint256 dueDate;
    uint256 fractions;
    IToken settlementToken;
}
