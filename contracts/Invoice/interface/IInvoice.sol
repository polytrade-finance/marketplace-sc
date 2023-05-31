// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interface/IDLT.sol";

interface IInvoice is IDLT {
    /**
     * @title A new struct to define the invoice information
     * @param Price, is the price of asset
     * @param rewardApr, is the Apr for calculating rewards
     * @param dueDate, is the end date for caluclating rewards
     * @param lastClaimDate, is the date of last claim rewards
     */
    struct InvoiceInfo {
        uint256 price;
        uint256 rewardApr;
        uint256 dueDate;
        uint256 lastClaimDate;
    }

    /**
     * @dev Emitted when `newURI` is set to the invoices instead of `oldURI`
     * @param oldBaseURI, Old base URI for the invoices
     * @param newBaseURI, New base URI for the invoices
     */
    event InvoiceBaseURISet(string oldBaseURI, string newBaseURI);

    /**
     * @dev Emitted when an invoice is created with it's parameters for an owner
     * @param creator, Address of the invoice creator
     * @param owner, Address of the initial onvoice owner
     * @param mainId, mainId is the unique identifier of invoice
     */
    event InvoiceCreated(
        address indexed creator,
        address indexed owner,
        uint256 indexed mainId
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Settles invoice for owner and burn the invoice
     * @param owner, current owner of invoice
     * @param mainId, unique identifier of invoice
     * @dev Needs marketplace access to settle an invoice
     * @return the invoice price
     */
    function settleInvoice(
        address owner,
        uint256 mainId
    ) external returns (uint256);

    /**
     * @dev Creates an invoice with its parameters
     * @param owner, initial owner of invoice
     * @param mainId, unique identifier of invoice
     * @param price, invoice price to sell
     * @param dueDate, end date for calculating rewards
     * @param apr, annual percentage rate for calculating rewards
     * @dev Needs admin access to create an invoice
     */
    function createInvoice(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) external;

    /**
     * @dev Creates batch invoice with their parameters
     * @param owners, initial owners of invoices
     * @param mainIds, unique identifiers of invoices
     * @param prices, invoices price to sell
     * @param dueDates, end dates for calculating rewards
     * @param aprs, annual percentage rates for calculating rewards
     * @dev Needs admin access to create an invoice
     */
    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata prices,
        uint256[] calldata dueDates,
        uint256[] calldata aprs
    ) external;

    /**
     * @dev Set a new baseURI for invoices
     * @dev Needs admin access to schange base URI
     * @param newBaseURI, string value of new URI
     */
    function setBaseURI(string calldata newBaseURI) external;

    /**
     * @dev Updates lastClaimDate whenever a buy or claimReward happens from marketplace
     * @dev Needs marketplace access to claim
     * @param owner, the address on asset owner
     * @param mainId, unique identifier of invoice
     * @return reward , accumulated rewards for the current owner
     */
    function claimReward(
        address owner,
        uint256 mainId
    ) external returns (uint256 reward);

    /**
     * @dev Calculates the remaning reward
     * @param mainId, unique identifier of invoice
     * @return result the rewards Amount
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 result);

    /**
     * @dev Calculates available rewards to claim
     * @param mainId, unique identifier of invoice
     * @return result the accumulated rewards amount for the current owner
     */
    function getAvailableReward(
        uint256 mainId
    ) external view returns (uint256 result);

    /**
     * @dev Gets the invoice information
     * @param mainId, unique identifier of invoice
     * @return InvoiceInfo struct
     */
    function getInvoiceInfo(
        uint256 mainId
    ) external view returns (InvoiceInfo calldata);

    /**
     * @dev concatenate invoiceId (mainId) to baseURI
     * @param mainId, unique identifier of invoice
     * @return string value of invoice URI
     */
    function tokenURI(uint256 mainId) external view returns (string memory);
}
