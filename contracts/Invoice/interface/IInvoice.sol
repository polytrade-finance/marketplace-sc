// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interface/IDLT.sol";

interface IInvoice is IDLT {
    /**
     * @title A new struct to define the metadata structure
     * @dev Defining a new type of struct called Metadata to store the asset metadata
     * @param lateFeePercentage, is a uint24 will have 2 decimals
     * @param gracePeriod, is a uint16 will have 2 decimals
     * @param dueDate, is a uint48 will have 2 decimals
     * @param invoiceDate, is a uint48 will have 2 decimals
     * @param fundsAdvancedDate, is a uint48 will have 2 decimals
     * @param invoiceAmount, is a uint will have 2 decimals
     */
    struct InitialMainMetadata {
        uint24 lateFeePercentage; // %
        uint16 gracePeriod; // days
        uint48 dueDate;
        uint48 invoiceDate;
        uint48 fundsAdvancedDate;
        uint256 invoiceAmount;
    }

    /**
     * @title A new struct to define the sub metadata structure
     * @dev Defining a new type of struct called Metadata to store the asset metadata
     * @param factoringFeePercentage, is a uint24 will have 2 decimals
     * @param discountFeePercentage, is a uint24 will have 2 decimals
     * @param bankChargesFeeAmount, is a uint24 will have 2 decimals
     * @param additionalFeeAmount, is a uint24 will have 2 decimals
     * @param advanceFeePercentage, is a uint16 will have 2 decimals
     */
    struct InitialSubMetadata {
        uint24 discountFeePercentage; // %
        uint24 factoringFeePercentage; // %
        uint24 additionalFeeAmount; // it's an amount
        uint24 bankChargesFeeAmount; // it's an amount
        uint16 advanceFeePercentage; // % advance ratio
    }

    /**
     * @title A new struct to define the metadata structure
     * @dev Defining a new type of struct called Metadata to store the asset metadata
     * @param paymentReceiptDate, is a uint48 will have 2 decimals
     * @param buyerAmountReceived, is a uint will have 2 decimals
     * @param reservePaidToSupplier, is a uint will have 2 decimals
     * @param amountSentToLender, is a uint will have 2 decimals
     * @param initialMetadata, is a InitialMetadata will hold all mandatory needed metadata to mint the AssetNFT
     */
    struct MainMetadata {
        uint48 paymentReceiptDate;
        uint buyerAmountReceived;
        uint reservePaidToSupplier;
        uint amountSentToLender;
        InitialMainMetadata initialMainMetadata;
    }

    /**
     * @dev Emitted when `newURI` is set to the Invoice category instead of `oldURI` by `mainId`
     * @param oldInvoiceBaseURI, Old Base URI for the Invoice category
     * @param newInvoiceBaseURI, New Base URI for the Invoice category
     */
    event InvoiceBaseURISet(string oldInvoiceBaseURI, string newInvoiceBaseURI);

    /**
     * @dev Emitted when `assetNumber` token with `metadata` is minted from the `creator` to the `owner`
     * @param creator, Address of the contract that minted
     * @param owner, Address of the receiver of this token
     * @param mainId, mainId of the newly minted token
     */
    event InvoiceCreated(
        address indexed creator,
        address indexed owner,
        uint indexed mainId
    );

    /**
     * @dev Emitted when `reservePaidToSupplier`, `paymentReserveDate`
     * & `amountSentToLender` metadata are updated on a specific `MainId`
     * @param mainId, Uint of the Invoice MainId
     * @param reservePaidToSupplier, Uint value of the reserved amount sent to supplier
     * @param paymentReceiptDate, Uint value of the reserve payment date
     * @param amountSentToLender, Uint value of the amount sent to the lender
     */
    event SettledMainMetadata(
        uint indexed mainId,
        uint paymentReceiptDate,
        uint reservePaidToSupplier,
        uint amountSentToLender
    );

    function setAssetSettledMetadata(
        uint mainId,
        uint paymentReceiptDate,
        uint reservePaidToSupplier,
        uint amountSentToLenders
    ) external;

    /**
     * @dev Calculate the net amount payable to the client
     * @return uint Net Amount Payable to the Client
     * @param mainId, Unique uint Invoice Number
     */
    function calculateNetAmountPayableToClient(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (int);

    /**
     * @dev Calculate the advanced amount
     * @return uint Advanced Amount
     * @param mainId, Unique uint Invoice Number
     * @param subId, Unique subId
     */
    function advanceAmountCalculation(
        uint mainId,
        uint subId,
        uint amount
    ) external view returns (uint);
}
