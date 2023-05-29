// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "./Interface/IInvoice.sol";

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

    function createInvoice(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createInvoice(owner, mainId, price, dueDate, apr);
    }

    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata price,
        uint256[] calldata dueDate,
        uint256[] calldata apr
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            owners.length == mainIds.length &&
                owners.length == price.length &&
                owners.length == dueDate.length &&
                owners.length == apr.length,
            "Invoice: No array parity"
        );

        for (uint256 i = 0; i < mainIds.length; ) {
            _createInvoice(owners[i], mainIds[i], price[i], dueDate[i], apr[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Implementation of a setter for the asset base URI
     * @param newBaseURI, String of the asset base URI
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
        if (invoice.lastSale == 0 && invoice.assetPrice != 0) {
            tenure = invoice.dueDate - block.timestamp;
            result = _calculateFormula(
                invoice.assetPrice,
                tenure,
                invoice.rewardApr
            );
        } else {
            tenure = invoice.dueDate - invoice.lastSale;
            result = _calculateFormula(
                invoice.assetPrice,
                tenure,
                invoice.rewardApr
            );
        }
    }

    /**
     * @dev Implementation of a getter for mainId URI
     * @return string URI for the invoice
     * @param mainId, Unique uint Invoice Number
     */
    function tokenURI(
        uint256 mainId
    ) public view virtual returns (string memory) {
        string memory stringInvoiceNumber = Strings.toString(mainId);
        return string.concat(_invoiceBaseURI, stringInvoiceNumber);
    }

    /**
     * @dev Implementation of a setter for the asset base URI
     * @param newBaseURI, String of the asset base URI
     */
    function _setBaseURI(string memory newBaseURI) private {
        string memory oldBaseURI = _invoiceBaseURI;
        _invoiceBaseURI = newBaseURI;
        emit InvoiceBaseURISet(oldBaseURI, newBaseURI);
    }

    function _createInvoice(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) private {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _invoices[mainId] = InvoiceInfo(price, apr, dueDate, 0, 0);
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
