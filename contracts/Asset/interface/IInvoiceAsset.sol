// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { InvoiceInfo } from "contracts/lib/structs.sol";

interface IInvoiceAsset {
    /**
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param invoiceMainId, invoiceMainId identifier
     * @param invoiceSubId, unique number of the invoice
     * @param settlePrice, paid amount for settlement
     */
    event InvoiceSettled(
        address indexed owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 settlePrice
    );

    /**
     * @dev Emitted when new rewards claimed by current owner
     * @param receiver, Address of reward receiver
     * @param invoiceMainId, invoice unique identifier
     * @param invoiceSubId, invoice unique identifier
     * @param reward, Amount of rewards received
     */
    event RewardsClaimed(
        address indexed receiver,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 reward
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Creates an invoice with its parameters
     * @param owner, address of the initial owner
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @param invoiceInfo, all related invoice information
     * @dev Needs asset originator access to create an invoice
     */
    function createInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        InvoiceInfo calldata invoiceInfo
    ) external;

    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata invoiceMainIds,
        uint256[] calldata invoiceSubIds,
        InvoiceInfo[] calldata invoiceInfos
    ) external;

    function settleInvoice(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address owner
    ) external;

    function batchSettleInvoice(
        uint256[] calldata invoiceMainIds,
        uint256[] calldata invoiceSubIds,
        address[] calldata owners
    ) external;

    /**
     * @dev Burns an invoice with its parameters
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @dev Needs admin access to burn an invoice
     */
    function burnInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 amount
    ) external;

    function getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256);

    function getRemainingReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward);

    /**
     * @dev Gets the invoice information
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @return InvoiceInfo struct
     */
    function getInvoiceInfo(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (InvoiceInfo memory);
}
