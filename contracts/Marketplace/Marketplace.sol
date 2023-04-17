// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/IMarketplace.sol";
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
     * @dev Implementation of the function used to buy Invoice amount
     * @param owner, address of the Invoice owner's
     * @param invoiceMainId, Uint unique number of the Invoice amount
     * @param subId, Uint number of the subId
     * @param amount, Uint number of the amount to be traded
     */
    function buy(
        address owner,
        uint invoiceMainId,
        uint subId,
        uint amount
    ) external {
        uint stableCointAmount = _invoiceCollection.calculateAdvanceAmount(
            invoiceMainId,
            subId,
            amount
        );

        _invoiceCollection.safeTransferFrom(
            owner,
            msg.sender,
            invoiceMainId,
            subId,
            amount,
            ""
        );

        _stableToken.transferFrom(msg.sender, owner, stableCointAmount);
    }

    /**
     * @dev Implementation of a getter for the Invocie Collection contract
     * @return address Address of the Invocie Collection contract
     */
    function getInvoiceCollection() external view returns (address) {
        return address(_invoiceCollection);
    }

    /**
     * @dev Implementation of a getter for the stable coin contract
     * @return address Address of the stable coin contract
     */
    function getStableCoin() external view returns (address) {
        return address(_stableToken);
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
