// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "contracts/Invoice/interface/IInvoice.sol";
import "contracts/Token//interface/IToken.sol";

/**
 * @title The common marketplace for the Invoices
 * @author Polytrade.Finance
 * @dev Implementation of all Invoices trading operations
 */
contract Marketplace is ERC165, AccessControl, IMarketplace {
    using ERC165Checker for address;

    uint256 public initialFee;
    uint256 public buyingFee;

    IInvoice private immutable _invoiceCollection;
    IToken private immutable _stableToken;

    address private _treasuryWallet;
    address private _feeWallet;

    bytes4 private constant _INVOICE_INTERFACE_ID = type(IInvoice).interfaceId;

    /**
     * @dev Constructor for the main Marketplace
     * @param invoiceCollection_, Address of the Invoice Collection used in the marketplace
     * @param tokenAddress_, Address of the ERC20 token address
     * @param treasuryWallet_, Address of the treasury wallet
     * @param feeWallet_, Address of the fee wallet
     */
    constructor(
        address invoiceCollection_,
        address tokenAddress_,
        address treasuryWallet_,
        address feeWallet_
    ) {
        if (!invoiceCollection_.supportsInterface(_INVOICE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(tokenAddress_ != address(0), "Invalid address");

        _invoiceCollection = IInvoice(invoiceCollection_);
        _stableToken = IToken(tokenAddress_);

        _setTreasuryWallet(treasuryWallet_);
        _setFeeWallet(feeWallet_);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev See {IMarketplace-settleInvoice}.
     */
    function settleInvoice(
        uint256 invoiceId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address owner = _invoiceCollection.getInvoiceInfo(invoiceId).owner;
        require(owner != address(0), "Invalid invoice id");
        _claimReward(invoiceId);

        _stableToken.transferFrom(
            _treasuryWallet,
            owner,
            _invoiceCollection.settleInvoice(invoiceId)
        );

        emit InvoiceSettled(owner, invoiceId);
    }

    /**
     * @dev See {IMarketplace-reList}.
     */
    function reList(uint256 invoiceId, uint256 salePrice) external {
        require(
            _invoiceCollection.getInvoiceInfo(invoiceId).owner == msg.sender,
            "You are not the owner"
        );

        _invoiceCollection.reList(invoiceId, salePrice);

        emit InvoiceRelisted(invoiceId, salePrice);
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(uint256 invoiceId) external {
        _buy(invoiceId);
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(uint256[] calldata invoiceIds) external {
        for (uint256 i = 0; i < invoiceIds.length; ) {
            _buy(invoiceIds[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function claimReward(uint256 invoiceId) external {
        require(
            _invoiceCollection.getInvoiceInfo(invoiceId).lastClaimDate != 0,
            "Asset not bought yet"
        );
        require(
            _invoiceCollection.getInvoiceInfo(invoiceId).owner == msg.sender,
            "You are not the owner"
        );
        _claimReward(invoiceId);
    }

    /**
     * @dev See {IMarketplace-setInitialFee}.
     */
    function setInitialFee(
        uint256 initialFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = initialFee;
        initialFee = initialFee_;

        emit InitialFeeSet(oldFee, initialFee);
    }

    /**
     * @dev See {IMarketplace-setBuyingFee}.
     */
    function setBuyingFee(
        uint256 buyingFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = buyingFee;
        buyingFee = buyingFee_;

        emit BuyingFeeSet(oldFee, buyingFee);
    }

    /**
     * @dev See {IMarketplace-setTreasuryWallet}.
     */
    function setTreasuryWallet(
        address newTreasuryWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryWallet(newTreasuryWallet);
    }

    /**
     * @dev See {IMarketplace-setFeeWallet}.
     */
    function setFeeWallet(
        address newFeeWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(IMarketplace).interfaceId ||
            super.supportsInterface(interfaceId);
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
        require(newFeeWallet != address(0), "Invalid wallet address");

        address oldFeeWallet = address(_feeWallet);
        _feeWallet = newFeeWallet;

        emit FeeWalletSet(oldFeeWallet, newFeeWallet);
    }

    /**
     * @dev Transfers invoice to buyer and transfer the price to treasury wallet
     * @param invoiceId, unique identifier of the Invoice
     */
    function _claimReward(uint256 invoiceId) private {
        address owner = _invoiceCollection.getInvoiceInfo(invoiceId).owner;
        uint256 reward = _invoiceCollection.claimReward(invoiceId);

        _stableToken.transferFrom(_treasuryWallet, owner, reward);

        emit RewardsClaimed(owner, reward);
    }

    /**
     * @dev Safe transfer invoice to buyer and transfer the price to treasury wallet
     * @dev Transfer buying fee or initial fee to fee wallet based on asset status
     * @param invoiceId, unique identifier of the Invoice
     */
    function _buy(uint256 invoiceId) private {
        uint256 price = _invoiceCollection.getInvoiceInfo(invoiceId).salePrice;
        require(price != 0, "Invoice is not listed");
        uint256 lastClaimDate = _invoiceCollection
            .getInvoiceInfo(invoiceId)
            .lastClaimDate;
        address owner = _invoiceCollection.getInvoiceInfo(invoiceId).owner;
        uint256 fee = lastClaimDate != 0 ? buyingFee : initialFee;
        address receiver = lastClaimDate != 0 ? owner : _treasuryWallet;

        fee = (price * fee) / 1e4;

        _claimReward(invoiceId);

        _invoiceCollection.changeOwner(msg.sender, invoiceId);

        _invoiceCollection.safeTransferFrom(
            owner,
            msg.sender,
            invoiceId,
            1,
            1,
            ""
        );

        _stableToken.transferFrom(msg.sender, receiver, price);
        _stableToken.transferFrom(msg.sender, _feeWallet, fee);

        emit AssetBought(owner, msg.sender);
    }
}
