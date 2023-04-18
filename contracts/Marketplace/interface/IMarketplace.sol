// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title The main interface to define the main marketplace
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the marketplace
 */
interface IMarketplace {
    /**
     * @dev Emitted when new `newInvoiceCollection` contract has been set instead of `OldInvoiceCollection`
     * @param oldInvoiceCollection, Old address of Invoice Collection contract token
     * @param newInvoiceCollection, New address of Invoice Collection contract token
     */
    event InvoiceCollectionSet(
        address oldInvoiceCollection,
        address newInvoiceCollection
    );

    /**
     * @dev Emitted when new `stableToken` contract has been set
     * @param stableToken, Address of ERC20 contract token
     */
    event StableTokenSet(address stableToken);
}
