// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./IMarketplace.sol";
import "../Invoice/interface/IInvoice.sol";
import "../Token/Token.sol";

/**
 * @title The common marketplace for the Invoices
 * @author Polytrade.Finance
 * @dev Implementation of all Invoices trading operations
 */
contract Marketplace is AccessControl, IMarketplace {
    IInvoice private _invoiceCollection;
    Token private _stableToken;

    /**
     * @dev Constructor for the main Marketplace
     * @param invoiceCollectionAddress, Address of the Invoice Collection used in the marketplace
     * @param stableTokenAddress, Address of the stableToken (ERC20) contract
     */
    constructor(address invoiceCollectionAddress, address stableTokenAddress) {
        _setInvoiceContract(invoiceCollectionAddress);
        _setStableToken(stableTokenAddress);
    }

    /**
     * @dev Implementation of a setter for Invoice Collection contract
     * @param newInvoiceCollectionAddress, Address of the Invoice Collection contract
     */
    function _setInvoiceContract(address newInvoiceCollectionAddress) private {
        address oldInvoiceCollectionAddress = address(_invoiceCollection);
        _invoiceCollection = IInvoice(newInvoiceCollectionAddress);

        emit InvoiceCollectionSet(
            oldInvoiceCollectionAddress,
            newInvoiceCollectionAddress
        );
    }

    /**
     * @dev Implementation of a setter for the ERC20 token
     * @param stableTokenAddress, Address of the stableToken (ERC20) contract
     */
    function _setStableToken(address stableTokenAddress) private {
        _stableToken = Token(stableTokenAddress);

        emit StableTokenSet(stableTokenAddress);
    }
}
