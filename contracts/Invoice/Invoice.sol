// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "contracts/Invoice/Interface/IInvoice.sol";

/**
 * @title The Invoice contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of invoice and rewards distribution
 */
contract Invoice is IInvoice, DLT, AccessControl {
    string private _invoiceBaseURI;
    uint256 private constant _YEAR = 365 days;

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
     * @dev See {IInvoice-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 result) {
        InvoiceInfo memory invoice = _invoices[mainId];
        uint256 tenure;
        if (invoice.lastClaim != 0) {
            tenure = invoice.dueDate - invoice.lastClaim;
            result = _calculateFormula(
                invoice.assetPrice,
                tenure,
                invoice.rewardApr
            );
        } else if (invoice.assetPrice != 0) {
            tenure = invoice.dueDate - block.timestamp;
            result = _calculateFormula(
                invoice.assetPrice,
                tenure,
                invoice.rewardApr
            );
        }
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
     * @dev Changes the invoice base URI
     * @param newBaseURI, String of the new invoice base URI
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
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _invoices[mainId] = InvoiceInfo(price, apr, dueDate, 0);
        _mint(owner, mainId, 1, 1);

        emit InvoiceCreated(msg.sender, owner, mainId);
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
