// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interface/IDLT.sol";

interface IInvoice is IDLT {
    /**
     * @title A new struct to define the invoice information
     * @param assetPrice, is the price of asset
     * @param rewardApr, is the Apr for calculating rewards
     * @param dueDate, is the end date for caluclating rewards
     * @param lastSale, is the date of last sale
     * @param lastClaim, is the date of last claim rewards
     */
    struct InvoiceInfo {
        uint256 assetPrice;
        uint256 rewardApr;
        uint256 dueDate;
        uint256 lastSale;
        uint256 lastClaim;
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
     * @dev Calculate the remaning reward
     * @param mainId, Unique uint256 invoice identifier
     * @return result the Rewards Amount
     */
    function getRemainingReward(
        uint mainId,
        uint subId,
        uint amount
    ) external view returns (uint);
}
