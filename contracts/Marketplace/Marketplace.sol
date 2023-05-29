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

    address private _treasuryWallet;

    /**
     * @dev Constructor for the main Marketplace
     * @param invoiceCollectionAddress, Address of the Invoice Collection used in the marketplace
     * @param stableTokenAddress, Address of the stableToken (ERC20) contract
     */
    constructor(
        address invoiceCollectionAddress,
        address stableTokenAddress,
        address treasuryWallet
    ) {
        _setInvoiceContract(invoiceCollectionAddress);
        _setStableToken(stableTokenAddress);

        _setTreasuryWallet(treasuryWallet);
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
        _buy(owner, invoiceMainId, subId, amount);
    }

    /**
     * @dev Implementation of the function used to buy Invoices
     * @param owners, addresses of the Invoice owner
     * @param invoiceMainIds, Uint unique numbers of the Invoices
     * @param subIds, Uint number of the subIds
     * @param amounts, Uint number of the amounts to be traded
     */
    function batchBuy(
        address[] calldata owners,
        uint[] calldata invoiceMainIds,
        uint[] calldata subIds,
        uint[] calldata amounts
    ) external {
        require(
            owners.length == invoiceMainIds.length &&
                owners.length == subIds.length &&
                owners.length == amounts.length,
            "Marketplace: No array parity"
        );

        for (uint counter = 0; counter < invoiceMainIds.length; ) {
            _buy(
                owners[counter],
                invoiceMainIds[counter],
                subIds[counter],
                amounts[counter]
            );

            unchecked {
                ++counter;
            }
        }
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
     * @dev Implementation of a getter for the stable coin contract
     * @return address Address of the stable coin contract
     */
    function getTreasuryWallet() external view returns (address) {
        return _treasuryWallet;
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

    /**
     * @dev Implementation of a setter for the Treasury Wallet
     * @param newTreasuryWallet, Address of the Treasury Wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        address oldTreasuryWallet = _treasuryWallet;
        _treasuryWallet = newTreasuryWallet;

        emit TreasuryWalletSet(oldTreasuryWallet, newTreasuryWallet);
    }

    /**
     * @dev Implementation of the function used to buy Invoice amount
     * @param owner, address of the Invoice owner's
     * @param invoiceMainId, Uint unique number of the Invoice amount
     * @param subId, Uint number of the subId
     * @param amount, Uint number of the amount to be traded
     */
    function _buy(
        address owner,
        uint invoiceMainId,
        uint subId,
        uint amount
    ) private {
        uint stableCoinAmount = _invoiceCollection.calculateAdvanceAmount(
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

        _stableToken.transferFrom(msg.sender, owner, stableCoinAmount);
    }
}
