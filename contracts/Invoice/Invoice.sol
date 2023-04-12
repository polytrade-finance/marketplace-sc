// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/DLT.sol";
import "./interface/IInvoice.sol";

contract Invoice is IInvoice, DLT {
    string private _invoiceBaseURI = "https://ipfs.io/ipfs";

    /**
     * @dev Mapping will be indexing the InitialMetadata for each Invoice category by its mainId
     */
    mapping(uint => InitialMetadata) private _metadata;

    /**
     * @dev Mapping will be indexing the URI for each Invoice category by its mainId
     */
    mapping(uint => string) private _invoiceURI;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_
    ) DLT(name, symbol) {
        _setBaseURI(baseURI_);
    }

    function createInvoice(
        address owner,
        uint256 mainId,
        string memory invoiceURI,
        InitialMetadata memory initialMetadata
    ) external {
        require(mainTotalSupply(mainId) == 0, "Invoice: Already minted");
        _metadata[mainId] = initialMetadata;

        _invoiceURI[mainId] = invoiceURI;
        _mint(owner, mainId, 1, initialMetadata.invoiceAmount);

        emit InvoiceCreated(msg.sender, owner, mainId);
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
