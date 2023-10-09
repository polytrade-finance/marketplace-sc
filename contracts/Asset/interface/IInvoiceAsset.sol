// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { InvoiceInfo } from "contracts/lib/structs.sol";

interface IInvoiceAsset {
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
     * @param settlePrice, paid amount for settlement
     */
    event InvoiceSettled(
        address indexed owner,
        uint256 invoiceMainId,
        uint256 settlePrice
    );

    /**
     * @dev Emitted when new rewards claimed by current owner
     * @param receiver, Address of reward receiver
     * @param invoiceMainId, invoice unique identifier
     * @param reward, Amount of rewards received
     */
    event RewardsClaimed(
        address indexed receiver,
        uint256 invoiceMainId,
        uint256 reward
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function setTreasuryWallet(address newTreasuryWallet) external;

    /**
     * @dev Creates an invoice with its parameters
     * @param owner, address of the initial owner
     * @param invoiceInfo, all related invoice information
     * @dev Needs asset originator access to create an invoice
     */
    function createInvoice(
        address owner,
        InvoiceInfo calldata invoiceInfo
    ) external returns (uint256);

    function batchCreateInvoice(
        address[] calldata owners,
        InvoiceInfo[] calldata invoiceInfos
    ) external returns (uint256[] memory);

    function settleInvoice(uint256 invoiceMainId, address owner) external;

    function batchSettleInvoice(
        uint256[] calldata invoiceMainIds,
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
        uint256 amount
    ) external;

    function getAvailableReward(
        uint256 invoiceMainId
    ) external view returns (uint256);

    function getRemainingReward(
        uint256 invoiceMainId
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
