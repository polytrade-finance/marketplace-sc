// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./interface/IMarketplace.sol";
import "../Invoice/interface/IInvoice.sol";
import "../Token/Token.sol";

/**
 * @title The common marketplace for the Invoices
 * @author Polytrade.Finance
 * @dev Implementation of all Invoices trading operations
 */
contract Marketplace is AccessControl, IMarketplace {
    using ERC165Checker for address;

    IInvoice private _invoiceCollection;
    Token private _stableToken;

    address private _treasuryWallet;
    address private _feeWallet;

    bytes4 private constant _INVOICE_INTERFACE_ID = type(IInvoice).interfaceId;

    /**
     * @dev Constructor for the main Marketplace
     * @param invoiceCollection, Address of the Invoice Collection used in the marketplace
     * @param stableToken, Address of the stableToken (ERC20) contract
     * @param treasuryWallet, Address of the treasury wallet
     * @param feeWallet, Address of the fee wallet
     */
    constructor(address invoiceCollection, address stableToken, address treasuryWallet, address feeWallet) {
        _setInvoiceContract(invoiceCollection);
        _setStableToken(stableToken);

        _setTreasuryWallet(treasuryWallet);
        _setFeeWallet(feeWallet);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(address owner, uint256 invoiceId) external {
        _buy(owner, invoiceId);
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(address[] calldata owners, uint256[] calldata invoiceIds) external {
        require(owners.length == invoiceIds.length, "Marketplace: No array parity");

        for (uint256 i = 0; i < invoiceIds.length;) {
            _buy(owners[i], invoiceIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function claimReward(uint256 invoiceId) external {
        require(_invoiceCollection.getInvoiceInfo(invoiceId).lastClaimDate != 0, "Asset not bought yet");
        _claimReward(invoiceId);
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function setTreasuryWallet(address newTreasuryWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryWallet(newTreasuryWallet);
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function setFeeWallet(address newFeeWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeWallet(newFeeWallet);
    }

    /**
     * @dev See {IMarketplace-getInvoiceCollection}.
     */
    function getInvoiceCollection() external view returns (address) {
        return address(_invoiceCollection);
    }

    /**
     * @dev See {IMarketplace-getStableToken}.
     */
    function getStableToken() external view returns (address) {
        return address(_stableToken);
    }

    /**
     * @dev See {IMarketplace-getTreasuryWallet}.
     */
    function getTreasuryWallet() external view returns (address) {
        return address(_treasuryWallet);
    }

    /**
     * @dev See {IMarketplace-getFeeWallet}.
     */
    function getFeeWallet() external view returns (address) {
        return address(_feeWallet);
    }

    /**
     * @notice Allows to set the address of the invoice collection contract
     * @param newInvoiceCollection, Invoice Collection contract
     */
    function _setInvoiceContract(address newInvoiceCollection) private {
        require(newInvoiceCollection != address(0), "Invalid collection address");

        if (!newInvoiceCollection.supportsInterface(_INVOICE_INTERFACE_ID))
            revert UnsupportedInterface();

        address oldInvoiceCollection = address(_invoiceCollection);
        _invoiceCollection = IInvoice(newInvoiceCollection);

        emit InvoiceCollectionSet(oldInvoiceCollection, newInvoiceCollection);
    }

    /**
     * @notice Allows to specify the stable token contract to be used for paying fees and price
     * @param tokenAddress, the ERC20 token address
     */
    function _setStableToken(address tokenAddress) private {
        require(tokenAddress != address(0), "Invalid address");

        _stableToken = Token(tokenAddress);

        emit StableTokenSet(tokenAddress);
    }

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @dev Wallet can be EOA or multisig
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        require(newTreasuryWallet != address(0), "Invalid wallet address");

        address oldTreasuryWallet = address(_treasuryWallet);
        _treasuryWallet = newTreasuryWallet;

        emit TreasuryWalletSet(oldTreasuryWallet, newTreasuryWallet);
    }

    /**
     * @notice Allows to set a new address for the fee wallet.
     * @dev Wallet can be EOA or multisig
     * @param newFeeWallet, Address of the new fee wallet
     */
    function _setFeeWallet(address newFeeWallet) private {
        require(newFeeWallet != address(0), "Marketplace: Invalid fee wallet address");

        address oldFeeWallet = address(_feeWallet);
        _feeWallet = newFeeWallet;

        emit FeeWalletSet(oldFeeWallet, newFeeWallet);
    }

    /**
     * @dev Transfers invoice to buyer and transfer the price to treasury wallet
     * @param invoiceId, unique identifier of the Invoice
     */
    function _claimReward(uint256 invoiceId) private {
        uint256 reward = _invoiceCollection.claimReward(msg.sender, invoiceId);

        _stableToken.transferFrom(_treasuryWallet, msg.sender, reward);
    }

    /**
     * @dev Safe transfer invoice to buyer and transfer the price to treasury wallet
     * @param owner, address of the Invoice owner's
     * @param invoiceId, unique identifier of the Invoice
     */
    function _buy(address owner, uint256 invoiceId) private {
        _claimReward(invoiceId);

        _invoiceCollection.safeTransferFrom(owner, msg.sender, invoiceId, 1, 1, "");

        uint256 price = _invoiceCollection.getInvoiceInfo(invoiceId).price;

        _stableToken.transferFrom(msg.sender, _treasuryWallet, price);
    }
}
