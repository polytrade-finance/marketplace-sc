// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interface/IDLT.sol";

interface IInvoice is IDLT {
    /**
     * @title A new struct to define the metadata structure
     * @dev Defining a new type of struct called Metadata to store the asset metadata
     * @param factoringFeePercentage, is a uint24 will have 2 decimals
     * @param discountFeePercentage, is a uint24 will have 2 decimals
     * @param lateFeePercentage, is a uint24 will have 2 decimals
     * @param bankChargesFeeAmount, is a uint24 will have 2 decimals
     * @param additionalFeeAmount, is a uint24 will have 2 decimals
     * @param advanceFeeAmount, is a uint16 will have 2 decimals
     * @param gracePeriod, is a uint16 will have 2 decimals
     * @param dueDate, is a uint48 will have 2 decimals
     * @param invoiceDate, is a uint48 will have 2 decimals
     * @param fundsAdvancedDate, is a uint48 will have 2 decimals
     * @param invoiceAmount, is a uint will have 2 decimals
     */
    struct InitialMetadata {
        uint24 factoringFeePercentage;
        uint24 discountFeePercentage;
        uint24 lateFeePercentage;
        uint24 bankChargesFeeAmount;
        uint24 additionalFeeAmount;
        uint16 advanceFeeAmount;
        uint16 gracePeriod;
        uint48 dueDate;
        uint48 invoiceDate;
        uint48 fundsAdvancedDate;
        uint256 invoiceAmount;
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
}
