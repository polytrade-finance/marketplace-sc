// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "./interface/IInvoice.sol";
import "../Formulas/interface/IFormulas.sol";

contract Invoice is ERC165, IInvoice, DLT, AccessControl {
    // Create a new role identifier for the minter role
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    IFormulas private _formulas;
    string private _invoiceBaseURI = "https://ipfs.io/ipfs";

    /**
     * @dev Mapping will be indexing the InitialMainMetadata for each Invoice category by its mainId
     */
    mapping(uint => InitialMainMetadata) private _mainMetadata;

    /**
     * @dev Mapping will be indexing the InitialSubMetadata for each Invoice category by its mainId and subId
     */
    mapping(uint => mapping(uint => InitialSubMetadata)) private _subMetadata;

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
        InitialMainMetadata calldata initialMainMetadata,
        InitialSubMetadata calldata initialSubMetadata
    ) external onlyRole(MINTER_ROLE) {
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
        InitialMainMetadata calldata initialMainMetadata,
        InitialSubMetadata calldata initialSubMetadata
    ) private {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _mainMetadata[mainId] = initialMainMetadata;
        _subMetadata[mainId][1] = initialSubMetadata;

        _mint(owner, mainId, 1, initialMainMetadata.invoiceAmount);

        emit InvoiceCreated(msg.sender, owner, mainId);
    }
}
