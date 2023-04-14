// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "./interface/IInvoice.sol";
import "../Formulas/interface/IFormulas.sol";

contract Invoice is IInvoice, DLT, AccessControl {
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IFormulas private _formulas;
    string private _invoiceBaseURI = "https://ipfs.io/ipfs";

    /**
     * @dev Mapping will be indexing the InitialMetadata for each Invoice category by its mainId
     */
    mapping(uint => InitialMetadata) private _metadata;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_,
        address formulas_
    ) DLT(name, symbol) {
        _setBaseURI(baseURI_);

        // TODO: create setter
        _formulas = IFormulas(formulas_);

        // Grant the minter role to a specified account
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function createInvoice(
        address owner,
        uint256 mainId,
        InitialMetadata calldata initialMetadata
    ) external onlyRole(MINTER_ROLE) {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _metadata[mainId] = initialMetadata;

        _mint(owner, mainId, 1, initialMetadata.invoiceAmount);

        emit InvoiceCreated(msg.sender, owner, mainId);
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
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function calculateAdvanceAmount(
        uint mainId,
        uint amount
    ) external view returns (uint) {
        InitialMetadata memory metadata = _metadata[mainId];

        return
            _formulas.advanceAmountCalculation(
                amount,
                metadata.advanceFeePercentage
            );
    }

    /**
     * @dev Implementation of a getter for mainId URI
     * @return string URI for the invoice
     * @param mainId, Unique uint Invoice Number
     */
    function tokenURI(uint mainId) public view virtual returns (string memory) {
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
}
