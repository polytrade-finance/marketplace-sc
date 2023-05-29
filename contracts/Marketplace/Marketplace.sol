// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Interface/IMarketplace.sol";
import "../Invoice/Interface/IInvoice.sol";
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
    address private _feeWallet;

    /**
     * @dev Constructor for the main Marketplace
     * @param invoiceCollection, Address of the Invoice Collection used in the marketplace
     * @param stableToken, Address of the stableToken (ERC20) contract
     * @param treasuryWallet, Address of the treasury wallet
     * @param feeWallet, Address of the fee wallet
     */
    constructor(
        IInvoice invoiceCollection,
        Token stableToken,
        address treasuryWallet,
        address feeWallet
    ) {
        _setInvoiceContract(invoiceCollection);
        _setStableToken(stableToken);

        _setTreasuryWallet(treasuryWallet);
        _setFeeWallet(feeWallet);
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
     * @dev Implementation of a getter for the treasury wallet
     * @return address Address of the treasury wallet
     */
    function getTreasuryWallet() external view returns (address) {
        return _treasuryWallet;
    }

    /**
     * @dev Implementation of a getter for the fee wallet
     * @return address Address of the fee wallet
     */
    function getFeeWallet() external view returns (address) {
        return _feeWallet;
    }

    /**
     * @dev Implementation of a setter for Invoice Collection contract
     * @notice This function allows to set the address of the Invoice Collection contract used within the marketplace.
     * @param newInvoiceCollection, Invoice Collection contract
     */
    function _setInvoiceContract(IInvoice newInvoiceCollection) private {
        address newInvoiceCollectionAddress = address(newInvoiceCollection);
        require(
            newInvoiceCollectionAddress != address(0),
            "Marketplace: Invalid invoice collection address"
        );

        address oldInvoiceCollectionAddress = address(_invoiceCollection);
        _invoiceCollection = newInvoiceCollection;

        emit InvoiceCollectionSet(
            oldInvoiceCollectionAddress,
            newInvoiceCollectionAddress
        );
    }

    /**
     * @notice This function allows to specify the stable coin address contract to be used within the marketplace.
     * @dev Implementation of a setter for the ERC20 token
     * @param stableToken, the stableToken (ERC20) contract
     */
    function _setStableToken(Token stableToken) private {
        address stableTokenAddress = address(stableToken);
        require(
            stableTokenAddress != address(0),
            "Marketplace: Invalid stable coin address"
        );

        _stableToken = stableToken;

        emit StableTokenSet(stableTokenAddress);
    }

    /**
     * @notice Updates the treasury wallet address used for funds allocation.
     * @dev This function allows to set a new treasury wallet address where funds will be allocated.
     * @dev Implementation of a setter for the treasury wallet
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        require(
            newTreasuryWallet != address(0),
            "Marketplace: Invalid treasury wallet address"
        );

        address oldTreasuryWallet = _treasuryWallet;
        _treasuryWallet = newTreasuryWallet;

        emit TreasuryWalletSet(oldTreasuryWallet, newTreasuryWallet);
    }

    /**
     * @notice This function allows to set a new address for the fee wallet.
     * @notice The fee wallet is responsible for collecting transaction fees.
     * @dev Implementation of a setter for the fee wallet
     * @param newFeeWallet, Address of the new fee wallet
     */
    function _setFeeWallet(address newFeeWallet) private {
        require(
            newFeeWallet != address(0),
            "Marketplace: Invalid fee wallet address"
        );

        address oldFeeWallet = _feeWallet;
        _feeWallet = newFeeWallet;

        emit FeeWalletSet(oldFeeWallet, newFeeWallet);
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