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

    /**
     * @dev Emitted when new `Treasury Wallet` has been set
     * @param oldTreasuryWallet, Address of the old treasury wallet
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    event TreasuryWalletSet(
        address oldTreasuryWallet,
        address newTreasuryWallet
    );

    /**
     * @dev Emitted when new `Fee Wallet` has been set
     * @param oldFeeWallet, Address of the old fee wallet
     * @param newFeeWallet, Address of the new fee wallet
     */
    event FeeWalletSet(address oldFeeWallet, address newFeeWallet);
}
