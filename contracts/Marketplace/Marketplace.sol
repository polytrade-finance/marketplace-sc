// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "contracts/Invoice/interface/IInvoice.sol";
import "contracts/Token/Token.sol";

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
     * @dev Buys
     * @param owner, address of the Invoice owner
     * @param invoiceId, unique number of the Invoice
     */
    function buy(address owner, uint invoiceId) external {
        _buy(owner, invoiceId);
    }

    /**
     * @dev Batch buy invoices from owners
     * @param owners, addresses of the invoice owners
     * @param invoiceIds, unique identifiers of the invoices
     */
    function batchBuy(
        address[] calldata owners,
        uint[] calldata invoiceIds
    ) external {
        require(
            owners.length == invoiceIds.length,
            "Marketplace: No array parity"
        );

        for (uint i = 0; i < invoiceIds.length; ) {
            _buy(owners[i], invoiceIds[i]);

            unchecked {
                ++i;
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
     * @dev Safe transfer invoice to buyer and transfer the price to treasury wallet
     * @param owner, address of the Invoice owner's
     * @param invoiceId, unique identifier of the Invoice
     */
    function _buy(address owner, uint invoiceId) private {
        _invoiceCollection.safeTransferFrom(
            owner,
            msg.sender,
            invoiceId,
            1,
            1,
            ""
        );

        uint256 price = _invoiceCollection.getInvoiceInfo(invoiceId).assetPrice;

        _stableToken.transferFrom(msg.sender, _treasuryWallet, price);
    }
}
