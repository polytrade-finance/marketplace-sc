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

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Transfer asset to buyer and price to treasuryWallet also deducts fee from buyer
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @dev Automatically claims rewards for prevoius owner
     * @param owner, address of the Invoice owner
     * @param invoiceId, unique number of the Invoice
     */
    function buy(address owner, uint256 invoiceId) external;

    /**
     * @dev Batch buy invoices from owners
     * @dev Loop through arrays and calls the buy function
     * @param owners, addresses of the invoice owners
     * @param invoiceIds, unique identifiers of the invoices
     */
    function batchBuy(
        address[] calldata owners,
        uint[] calldata invoiceIds
    ) external;

    /**
     * @dev claim available rewards for current owner
     * @dev updates lastClaimDate for the invoice in the Invoice contract
     * @dev Caller should own the invoiceId
     * @param invoiceId, unique number of the Invoice
     */
    function claimReward(uint256 invoiceId) external;

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function setTreasuryWallet(address newTreasuryWallet) external;

    /**
     * @dev Allows to set a new fee wallet address where buying fees will be allocated.
     * @param newFeeWallet, Address of the new fee wallet
     */
    function setFeeWallet(address newFeeWallet) external;

    /**
     * @dev Gets current invoice collection address
     * @return address, Address of the invocie collection contract
     */
    function getInvoiceCollection() external view returns (address);

    /**
     * @dev Gets current stable token address
     * @return address, Address of the stable token contract
     */
    function getStableToken() external view returns (address);

    /**
     * @dev Gets current treasury wallet address
     * @return address, Address of the treasury wallet
     */
    function getTreasuryWallet() external view returns (address);

    /**
     * @dev Gets current fee wallet address
     * @return address Address of the fee wallet
     */
    function getFeeWallet() external view returns (address);
}
