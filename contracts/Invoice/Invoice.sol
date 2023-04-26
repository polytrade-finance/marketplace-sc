// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "./interface/IInvoice.sol";
import "../Formulas/interface/IFormulas.sol";
import "../Token/Token.sol";

contract Invoice is IInvoice, DLT, AccessControl {
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IFormulas private _formulas;
    Token private _stableToken;

    string private _invoiceBaseURI = "https://ipfs.io/ipfs";

    /**
     * @dev Mapping will be indexing the InitialMainMetadata for each Invoice category by its mainId
     */
    mapping(uint => MainMetadata) private _mainMetadata;

    /**
     * @dev Mapping will be indexing the InitialSubMetadata for each Invoice category by its mainId and subId
     */
    mapping(uint => mapping(uint => InitialSubMetadata)) private _subMetadata;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_,
        address formulas_,
        address stableTokenAddress
    ) DLT(name, symbol) {
        _setBaseURI(baseURI_);

        // TODO: create setters
        _formulas = IFormulas(formulas_);
        _stableToken = Token(stableTokenAddress);

        // Grant the minter role to a specified account
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function createInvoice(
        address owner,
        uint256 mainId,
        InitialMainMetadata calldata initialMainMetadata,
        InitialSubMetadata calldata initialSubMetadata
    ) external onlyRole(MINTER_ROLE) {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _mainMetadata[mainId].initialMainMetadata = initialMainMetadata;
        _subMetadata[mainId][1] = initialSubMetadata;

        _mint(owner, mainId, 1, initialMainMetadata.invoiceAmount);

        emit InvoiceCreated(msg.sender, owner, mainId);
    }

    function setAssetSettledMetadata(
        uint mainId,
        uint paymentReceiptDate,
        uint reservePaidToSupplier,
        uint amountSentToLenders
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setAssetSettledMetadata(
            mainId,
            paymentReceiptDate,
            reservePaidToSupplier,
            amountSentToLenders
        );
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
        uint subId,
        uint amount
    ) external view returns (uint) {
        InitialSubMetadata memory initialSubMetadata = _subMetadata[mainId][
            subId
        ];

        return
            _formulas.advanceAmountCalculation(
                amount,
                initialSubMetadata.advanceFeePercentage
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

    /**
     * @dev Implementation of a setter for
     * reserved payment date & amount sent to supplier & the payment transaction ID & amount sent to lender
     * @param mainId, Unique uint MainId of the Invoice
     * @param reservePaidToSupplier, Uint value of the reserved amount sent to supplier
     * @param paymentReceiptDate, Uint value of the reserve payment date
     * @param amountSentToLender, Uint value of the amount sent to the lender
     */
    function _setAssetSettledMetadata(
        uint mainId,
        uint paymentReceiptDate,
        uint reservePaidToSupplier,
        uint amountSentToLender
    ) private {
        require(
            _mainMetadata[mainId].reservePaidToSupplier == 0 &&
                _mainMetadata[mainId].paymentReceiptDate == 0 &&
                _mainMetadata[mainId].amountSentToLender == 0,
            "Asset is already settled"
        );

        _mainMetadata[mainId].paymentReceiptDate = uint48(paymentReceiptDate);
        _mainMetadata[mainId].reservePaidToSupplier = reservePaidToSupplier;

        emit SettledMainMetadata(
            mainId,
            reservePaidToSupplier,
            paymentReceiptDate,
            amountSentToLender
        );
    }
}
