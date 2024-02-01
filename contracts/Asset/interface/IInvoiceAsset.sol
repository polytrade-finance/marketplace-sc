// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { InvoiceInfo, IERC20 } from "contracts/lib/structs.sol";
import { GenericErrors } from "contracts/lib/errors.sol";

interface IInvoiceAsset is GenericErrors {
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
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param invoiceMainId, invoiceMainId identifier
     * @param invoiceSubId, invoiceSubId identifier
     * @param settlePrice, paid amount for settlement
     * @param token, address of token used for settlement
     */
    event InvoiceSettled(
        address indexed owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 settlePrice,
        address token
    );

    /**
     * @dev Emitted when new rewards claimed by current owner
     * @param receiver, Address of reward receiver
     * @param invoiceMainId, invoice unique identifier
     * @param invoiceSubId, invoice unique identifier
     * @param reward, Amount of rewards received
     * @param token, address of token used for claiming rewards
     */
    event RewardsClaimed(
        address indexed receiver,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 reward,
        address token
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    error InvalidRewardApr();
    error InvoiceAlreadyCreated();
    error InvalidInvoiceId();

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function setTreasuryWallet(address newTreasuryWallet) external;

    /**
     * @dev Mint a new subId by incrementing whenever a buy happens on marketplace from subId zero
     * @param buyer, Address of buyer of subId
     * @param mainId, The unique identifier of asset
     * @param fractions, number of fraction to create
     */
    function onSubIdCreation(
        address buyer,
        uint256 mainId,
        uint256 fractions
    ) external;

    /**
     * @dev Creates an invoice with its parameters
     * @param invoiceInfo, all related invoice information
     * @dev Needs asset originator access to create an invoice
     */
    function createInvoice(
        InvoiceInfo calldata invoiceInfo
    ) external returns (uint256);

    /**
     * @dev Batch creates invoices with their parameters
     * @param invoiceInfos, all related invoice informations
     * @dev Needs asset originator access to create invoices
     */
    function batchCreateInvoice(
        InvoiceInfo[] calldata invoiceInfos
    ) external returns (uint256[] memory);

    /**
     * @dev Settle an invoice for the a specific owner
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @param owner, address of specified owner
     * @dev Needs asset originator access to settle an invoice
     */
    function settleInvoice(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address owner
    ) external;

    /**
     * @dev Batch settle invoices for the a specific owners
     * @param invoiceMainIds, unique identifiers of invoices
     * @param invoiceSubIds, unique identifiers of invoices
     * @param owners, addresses of specified owners
     * @dev Needs asset originator access to settle invoices
     */
    function batchSettleInvoice(
        uint256[] calldata invoiceMainIds,
        uint256[] calldata invoiceSubIds,
        address[] calldata owners
    ) external;

    /**
     * @dev Burns an invoice with its parameters
     * @param invoiceMainId, unique identifier of invoice
     * @dev Needs admin access to burn an invoice
     */
    function burnInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 amount
    ) external;

    /**
     * @dev Gets available rewards for claiming
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     */
    function getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256);

    /**
     * @dev Gets remaning rewards till due date
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     */
    function getRemainingReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward);

    /**
     * @dev Gets current treasury wallet address
     * @return address, Address of the treasury wallet
     */
    function getTreasuryWallet() external view returns (address);

    /**
     * @dev Gets the invoice information
     * @param invoiceMainId, unique identifier of invoice
     * @return InvoiceInfo struct
     */
    function getInvoiceInfo(
        uint256 invoiceMainId
    ) external view returns (InvoiceInfo memory);
}
