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
    Token private immutable _stableToken;

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
        _createInvoice(owner, mainId, initialMainMetadata, initialSubMetadata);
    }

    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata mainIds,
        InitialMainMetadata[] calldata initialMainMetadata,
        InitialSubMetadata[] calldata initialSubMetadata
    ) external onlyRole(MINTER_ROLE) {
        require(
            owners.length == mainIds.length &&
                owners.length == initialMainMetadata.length &&
                owners.length == initialSubMetadata.length,
            "Invoice: No array parity"
        );

        for (uint counter = 0; counter < mainIds.length; ) {
            _createInvoice(
                owners[counter],
                mainIds[counter],
                initialMainMetadata[counter],
                initialSubMetadata[counter]
            );

            unchecked {
                ++counter;
            }
        }
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
    function advanceAmountCalculation(
        uint mainId,
        uint subId,
        uint amount
    ) external view returns (uint) {
        return _advanceAmountCalculation(mainId, subId, amount);
    }

    /**
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function factoringFeeAmountCalculation(
        uint mainId,
        uint subId,
        uint amount
    ) external view returns (uint) {
        return _factoringFeeAmountCalculation(mainId, subId, amount);
    }

    /**
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function lateDaysCalculation(uint mainId) external view returns (uint) {
        return _lateDaysCalculation(mainId);
    }

    /**
     * @dev Calculate the discount amount
     * @return uint Amount of the Discount
     * @param mainId, Unique uint Invoice Number
     */
    function discountAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (uint) {
        return _discountAmountCalculation(mainId, subId, amount);
    }

    /**
     * @dev Calculate the total fees amount
     * @return uint Total Amount
     * @param mainId, Unique uint Invoice Number
     */
    function totalFeesAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (uint) {
        return _totalFeesAmountCalculation(mainId, subId, amount);
    }

    /**
     * @dev Calculate the late amount
     * @return uint Late Amount
     * @param mainId, Unique uint Invoice Number
     */
    function lateFeeAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        uint lateDays = _lateDaysCalculation(mainId);

        uint advancedAmount = _advanceAmountCalculation(mainId, subId, amount);
        return
            _formulas.lateFeeAmountCalculation(
                mainMetadata.initialMainMetadata.lateFeePercentage,
                lateDays,
                advancedAmount
            );
    }

    /**
     * @dev Calculate the total amount received
     * @return uint Total Received Amount
     * @param mainId, Unique uint Invoice Number
     */
    function calculateTotalAmountReceived(
        uint mainId
    ) external view returns (uint) {
        return _calculateTotalAmountReceived(mainId);
    }

    /**
     * @dev Calculate the net amount payable to the client
     * @return uint Net Amount Payable to the Client
     * @param mainId, Unique uint Invoice Number
     */
    function calculateNetAmountPayableToClient(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (int) {
        uint advancedAmount = _advanceAmountCalculation(mainId, subId, amount);

        uint totalAmountReceived = _calculateTotalAmountReceived(mainId);

        uint totalFeesAmount = _totalFeesAmountCalculation(
            mainId,
            subId,
            amount
        );

        return
            _formulas.netAmountPayableToClientCalculation(
                totalAmountReceived,
                advancedAmount,
                totalFeesAmount
            );
    }

    /**
     * @dev Calculate the reserve amount
     * @return uint Reserve Amount
     * @param mainId, Unique uint Invoice
     */
    function reserveAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) external view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        uint advancedAmount = _advanceAmountCalculation(mainId, subId, amount);

        return
            _formulas.reserveAmountCalculation(
                mainMetadata.initialMainMetadata.invoiceAmount,
                advancedAmount
            );
    }

    /**
     * @dev Calculate the tenure
     * @return uint Invoice Tenure or Finance Tenure
     * @param mainId, Unique uint Invoice Number
     */
    function calculateTenure(uint mainId) external view returns (uint) {
        return _calculateTenure(mainId);
    }

    /**
     * @dev Calculate the invoice tenure
     * @return uint Invoice Tenure
     * @param mainId, Unique uint Invoice Number
     */
    function calculateInvoiceTenure(uint mainId) external view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        return
            _formulas.invoiceTenureCalculation(
                mainMetadata.initialMainMetadata.dueDate,
                mainMetadata.initialMainMetadata.invoiceDate
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

    function _createInvoice(
        address owner,
        uint256 mainId,
        InitialMainMetadata calldata initialMainMetadata,
        InitialSubMetadata calldata initialSubMetadata
    ) private {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _mainMetadata[mainId].initialMainMetadata = initialMainMetadata;
        _subMetadata[mainId][1] = initialSubMetadata;

        _mint(owner, mainId, 1, initialMainMetadata.invoiceAmount);

        emit InvoiceCreated(msg.sender, owner, mainId);
    }

    /**
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function _advanceAmountCalculation(
        uint mainId,
        uint subId,
        uint amount
    ) private view returns (uint) {
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
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function _factoringFeeAmountCalculation(
        uint mainId,
        uint subId,
        uint amount
    ) private view returns (uint) {
        InitialSubMetadata memory initialSubMetadata = _subMetadata[mainId][
            subId
        ];

        return
            _formulas.factoringFeeAmountCalculation(
                amount,
                initialSubMetadata.factoringFeePercentage
            );
    }

    /**
     * @dev Calculate the advanced amount
     * @return uint Advance Amount
     * @param mainId, Unique uint Invoice Number
     */
    function _lateDaysCalculation(uint mainId) private view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        return
            _formulas.lateDaysCalculation(
                mainMetadata.paymentReceiptDate,
                mainMetadata.initialMainMetadata.dueDate,
                mainMetadata.initialMainMetadata.lateFeePercentage
            );
    }

    /**
     * @dev Calculate the discount amount
     * @return uint Amount of the Discount
     * @param mainId, Unique uint Invoice Number
     */
    function _discountAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) private view returns (uint) {
        InitialSubMetadata memory initialSubMetadata = _subMetadata[mainId][
            subId
        ];

        uint tenure = _calculateTenure(mainId);

        uint lateDays = _lateDaysCalculation(mainId);

        uint advancedAmount = _advanceAmountCalculation(mainId, subId, amount);
        return
            _formulas.discountAmountCalculation(
                initialSubMetadata.discountFeePercentage,
                tenure,
                lateDays,
                advancedAmount
            );
    }

    /**
     * @dev Calculate the total fees amount
     * @return uint Total Amount
     * @param mainId, Unique uint Invoice Number
     */
    function _totalFeesAmountCalculation(
        uint mainId,
        uint256 subId,
        uint256 amount
    ) private view returns (uint) {
        InitialSubMetadata memory initialSubMetadata = _subMetadata[mainId][
            subId
        ];

        uint factoringAmount = _factoringFeeAmountCalculation(
            mainId,
            subId,
            amount
        );

        uint discountAmount = _discountAmountCalculation(mainId, subId, amount);

        return
            _formulas.totalFeesAmountCalculation(
                factoringAmount,
                discountAmount,
                initialSubMetadata.additionalFeeAmount,
                initialSubMetadata.bankChargesFeeAmount
            );
    }

    /**
     * @dev Calculate the total amount received
     * @return uint Total Received Amount
     * @param mainId, Unique uint Invoice Number
     */
    function _calculateTotalAmountReceived(
        uint mainId
    ) private view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        return
            _formulas.totalAmountReceivedCalculation(
                mainMetadata.buyerAmountReceived,
                mainMetadata.reservePaidToSupplier
            );
    }

    /**
     * @dev Calculate the tenure
     * @return uint Invoice Tenure or Finance Tenure
     * @param mainId, Unique uint Invoice Number
     */
    function _calculateTenure(uint mainId) private view returns (uint) {
        MainMetadata memory mainMetadata = _mainMetadata[mainId];

        if (mainMetadata.paymentReceiptDate == 0) {
            return
                _formulas.invoiceTenureCalculation(
                    mainMetadata.initialMainMetadata.dueDate,
                    mainMetadata.initialMainMetadata.invoiceDate
                );
        }

        return
            _formulas.financeTenureCalculation(
                mainMetadata.paymentReceiptDate,
                mainMetadata.initialMainMetadata.fundsAdvancedDate
            );
    }
}
