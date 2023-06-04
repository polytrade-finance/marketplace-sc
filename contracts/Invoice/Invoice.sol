// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "contracts/Invoice/interface/IInvoice.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";

/**
 * @title The Invoice contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of invoice and rewards distribution
 */
contract Invoice is ERC165, IInvoice, DLT, AccessControl {
    using ERC165Checker for address;

    // Create a new role identifier for the marketplace role
    bytes32 public constant MARKETPLACE_ROLE =
        0x0ea61da3a8a09ad801432653699f8c1860b1ae9d2ea4a141fadfd63227717bc8;

    string private _invoiceBaseURI;
    uint256 private constant _YEAR = 365 days;

    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

    /**
     * @dev Mapping will be indexing the InvoiceInfo for each Invoice category by its mainId
     */
    mapping(uint256 => InvoiceInfo) private _invoices;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_
    ) DLT(name, symbol) {
        _setBaseURI(baseURI_);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev See {IInvoice-createInvoice}.
     */
    function createInvoice(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createInvoice(owner, mainId, price, dueDate, apr);
    }

    /**
     * @dev See {IInvoice-settleInvoice}.
     */
    function settleInvoice(
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) returns (uint256 price) {
        if (!msg.sender.supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();
        InvoiceInfo memory invoice = _invoices[mainId];

        require(block.timestamp > invoice.dueDate, "Due date not passed");

        price = invoice.price;
        _burn(invoice.owner, mainId, 1, 1);
        delete _invoices[mainId];
    }

    /**
     * @dev See {IInvoice-batchCreateInvoice}.
     */
    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            owners.length == mainIds.length &&
                owners.length == prices.length &&
                owners.length == dueDates.length &&
                owners.length == aprs.length,
            "Invoice: No array parity"
        );

        for (uint256 i = 0; i < mainIds.length; ) {
            _createInvoice(
                owners[i],
                mainIds[i],
                prices[i],
                dueDates[i],
                aprs[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IInvoice-setBaseURI}.
     */
    function setBaseURI(
        string calldata newBaseURI
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(newBaseURI);
    }

    /**
     * @dev See {IInvoice-changeOwner}.
     */
    function changeOwner(
        address newOwner,
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) {
        if (!msg.sender.supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();

        InvoiceInfo storage invoice = _invoices[mainId];

        invoice.salePrice = 0;
        invoice.owner = newOwner;
    }

    /**
     * @dev See {IInvoice-claimReward}.
     */
    function claimReward(
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) returns (uint256 reward) {
        if (!msg.sender.supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();
        InvoiceInfo storage invoice = _invoices[mainId];

        reward = _getAvailableReward(mainId);

        invoice.lastClaimDate = (
            block.timestamp > invoice.dueDate
                ? invoice.dueDate
                : block.timestamp
        );
    }

    /**
     * @dev See {IInvoice-reList}.
     */
    function reList(
        uint256 mainId,
        uint256 salePrice
    ) external onlyRole(MARKETPLACE_ROLE) {
        _invoices[mainId].salePrice = salePrice;
        _approve(_invoices[mainId].owner, msg.sender, mainId, 1, 1);
    }

    /**
     * @dev See {IInvoice-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoices[mainId];
        uint256 tenure;

        if (invoice.lastClaimDate != 0) {
            tenure = invoice.dueDate - invoice.lastClaimDate;
            reward = _calculateFormula(
                invoice.price,
                tenure,
                invoice.rewardApr
            );
        } else if (invoice.price != 0) {
            tenure =
                invoice.dueDate -
                (
                    block.timestamp > invoice.dueDate
                        ? invoice.dueDate
                        : block.timestamp
                );
            reward = _calculateFormula(
                invoice.price,
                tenure,
                invoice.rewardApr
            );
        }
    }

    /**
     * @dev See {IInvoice-getAvailableReward}.
     */
    function getAvailableReward(
        uint256 mainId
    ) external view returns (uint256) {
        return _getAvailableReward(mainId);
    }

    /**
     * @dev See {IInvoice-getInvoiceInfo}.
     */
    function getInvoiceInfo(
        uint256 mainId
    ) external view returns (InvoiceInfo memory) {
        return _invoices[mainId];
    }

    /**
     * @dev See {IInvoice-tokenURI}.
     */
    function tokenURI(uint256 mainId) external view returns (string memory) {
        string memory stringInvoiceNumber = Strings.toString(mainId);
        return string.concat(_invoiceBaseURI, stringInvoiceNumber);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(IInvoice).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Changes the invoice base URI
     * @param newBaseURI, String of the asset base URI
     */
    function _setBaseURI(string memory newBaseURI) private {
        string memory oldBaseURI = _invoiceBaseURI;
        _invoiceBaseURI = newBaseURI;
        emit InvoiceBaseURISet(oldBaseURI, newBaseURI);
    }

    /**
     * @dev Creates a new invoice with given mainId and transfer it to owner
     * @param owner, Address of the initial invoice owner
     * @param mainId, unique identifier of invoice
     * @param price, Invoice price to buy
     * @param dueDate, is the end date for caluclating rewards
     * @param apr, is the annual percentage rate for calculating rewards
     */
    function _createInvoice(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) private {
        require(owner != address(0), "Invalid owner address");
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _invoices[mainId] = InvoiceInfo(owner, price, price, apr, dueDate, 0);
        _mint(owner, mainId, 1, 1);

        emit InvoiceCreated(msg.sender, owner, mainId);
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param mainId, unique identifier of invoice
     * @return reward , accumulated rewards for the current owner
     */
    function _getAvailableReward(
        uint256 mainId
    ) private view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoices[mainId];

        if (invoice.lastClaimDate != 0) {
            uint256 tenure = (
                block.timestamp > invoice.dueDate
                    ? invoice.dueDate
                    : block.timestamp
            ) - invoice.lastClaimDate;

            reward = _calculateFormula(
                invoice.price,
                tenure,
                invoice.rewardApr
            );
        }
    }

    /**
     * @dev Calculates the rewards for a given asset
     * @param price is the price of invoice
     * @param tenure is the duration from last updated rewards
     * @param apr is the annual percentage rate of rewards for assets
     */
    function _calculateFormula(
        uint256 price,
        uint256 tenure,
        uint256 apr
    ) private pure returns (uint256) {
        return ((price * tenure * apr) / 1e4) / _YEAR;
    }
}
