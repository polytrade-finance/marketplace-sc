// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { InvoiceInfo, IInvoiceAsset, IERC20 } from "contracts/Asset/interface/IInvoiceAsset.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ListedInfo, IMarketplace } from "contracts/Marketplace/interface/IMarketplace.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { Counters } from "contracts/lib/Counters.sol";

/**
 * @title The asset contract based on ERC6960
 * @author Polytrade.Finance
 * @dev Manages creation of asset and rewards distribution
 */
contract InvoiceAsset is Initializable, Context, AccessControl, IInvoiceAsset {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;
    using Counters for Counters.Counter;

    IBaseAsset private _assetCollection;
    IMarketplace private _marketplace;
    Counters.Counter private _nonce;

    address private _treasuryWallet;

    // solhint-disable-next-line
    uint256 private CHAIN_ID;

    /// @notice The commercial year consists of a 360-day period, 12 months of 30 days each, as utilized by Polytrade
    uint256 private constant _YEAR = 360 days;

    uint256 private constant _PRECISION = 1e8;

    mapping(uint256 => InvoiceInfo) private _invoiceInfo;
    mapping(uint256 => mapping(uint256 => uint256)) private _purchaseDate;
    mapping(uint256 => uint256) private _currentSubId;

    // Create a new role identifier for the asset originator
    bytes32 public constant ASSET_ORIGINATOR =
        0x6515eccc42cea4c6b51e4cf769f86c1580ce4efeb1d5bee305af7f36bbb6ce6e;

    // Create a new role identifier for the marketplace role
    bytes32 public constant MARKETPLACE_ROLE =
        0x0ea61da3a8a09ad801432653699f8c1860b1ae9d2ea4a141fadfd63227717bc8;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;
    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

    /**
     * @dev Initializer for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     * @param treasuryWallet_, Address of the treasury wallet
     */
    function initialize(
        address assetCollection_,
        address treasuryWallet_,
        address marketplace_
    ) external initializer {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        if (!marketplace_.supportsInterface(_MARKETPLACE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        _assetCollection = IBaseAsset(assetCollection_);
        _marketplace = IMarketplace(marketplace_);
        CHAIN_ID = block.chainid;

        _setTreasuryWallet(treasuryWallet_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ASSET_ORIGINATOR, _msgSender());
    }

    /**
     * @dev See {IInvoiceAsset-setTreasuryWallet}.
     */
    function setTreasuryWallet(
        address newTreasuryWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryWallet(newTreasuryWallet);
    }

    /**
     * @dev See {IInvoiceAsset-createInvoice}.
     */
    function createInvoice(
        bool priceIsLocked,
        InvoiceInfo calldata invoiceInfo
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256) {
        return _createInvoice(priceIsLocked, invoiceInfo);
    }

    /**
     * @dev See {IInvoiceAsset-batchCreateInvoice}.
     */
    function batchCreateInvoice(
        bool[] calldata priceIsLocked,
        InvoiceInfo[] calldata invoiceInfos
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256[] memory) {
        uint256 length = invoiceInfos.length;
        if (priceIsLocked.length != length) {
            revert NoArrayParity();
        }
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _createInvoice(priceIsLocked[i], invoiceInfos[i]);

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
     * @dev See {IInvoiceAsset-settleInvoice}.
     */
    function settleInvoice(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address owner
    ) external onlyRole(ASSET_ORIGINATOR) {
        _settleInvoice(invoiceMainId, invoiceSubId, owner);
    }

    /**
     * @dev See {IInvoiceAsset-batchSettleInvoice}.
     */
    function batchSettleInvoice(
        uint256[] calldata invoiceMainIds,
        uint256[] calldata invoiceSubIds,
        address[] calldata owners
    ) external onlyRole(ASSET_ORIGINATOR) {
        uint256 length = invoiceMainIds.length;
        if (owners.length != length || invoiceSubIds.length != length) {
            revert NoArrayParity();
        }

        for (uint256 i = 0; i < length; ) {
            _settleInvoice(invoiceMainIds[i], invoiceSubIds[i], owners[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IInvoiceAsset-burnInvoice}.
     */
    function burnInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetCollection.burnAsset(owner, invoiceMainId, invoiceSubId, amount);
        uint256 totalSubSupply = _assetCollection.totalSubSupply(
            invoiceMainId,
            invoiceSubId
        );

        _invoiceInfo[invoiceMainId].fractions = totalSubSupply;

        if (totalSubSupply == 0) {
            delete _invoiceInfo[invoiceMainId];
        }
    }

    /**
     * @dev See {IInvoiceAsset-onSubIdCreation}.
     */
    function onSubIdCreation(
        address buyer,
        uint256 invoiceMainId,
        uint256 fractions,
        uint256 price
    ) external onlyRole(MARKETPLACE_ROLE) {
        _currentSubId[invoiceMainId] += 1;
        _purchaseDate[invoiceMainId][_currentSubId[invoiceMainId]] = block
            .timestamp;
        _assetCollection.setTradingRecord(
            buyer,
            invoiceMainId,
            _currentSubId[invoiceMainId],
            price
        );

        _assetCollection.burnAsset(
            _assetCollection.getAssetInfo(invoiceMainId, 0).initialOwner,
            invoiceMainId,
            0,
            fractions
        );
        _assetCollection.createAsset(
            buyer,
            invoiceMainId,
            _currentSubId[invoiceMainId],
            fractions
        );
    }

    /**
     * @dev See {IInvoiceAsset-getNonce}.
     */
    function getNonce(address account) external view returns (uint256) {
        return _nonce.current(account);
    }

    /**
     * @dev See {IInvoiceAsset-getRemainingTenure}.
     */
    function getRemainingTenure(
        uint256 invoiceMainId
    ) external view returns (uint256 apr) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];

        return
            _calculateRemainingTenure(
                invoice.invoiceDate,
                invoice.dueDate,
                invoice.tenure
            );
    }

    /**
     * @dev See {IGenericAsset-getApr}.
     */
    function getApr(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 apr) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        ListedInfo memory listedInfo = _marketplace.getListedInfo(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 _tradingRecord = _assetCollection.getTradingRecord(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 userFractions = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 remainingTenure = _calculateRemainingTenure(
            invoice.invoiceDate,
            invoice.dueDate,
            invoice.tenure
        );

        uint256 price = listedInfo.salePrice != 0 ? listedInfo.salePrice : _tradingRecord;

        if (remainingTenure == 0 || _tradingRecord == 0) {
            apr = 0;
        } else {
            apr = _calculateApr(
                price,
                invoice.fractions,
                userFractions,
                remainingTenure,
                invoice.dueAmount
            );
        }
    }

    /**
     * @dev See {IGenericAsset-getPrice}.
     */
    function getPrice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256) {
        uint256 userFractions = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        if (userFractions == 0) {
            return 0;
        }

        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        ListedInfo memory listedInfo = _marketplace.getListedInfo(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        uint256 remainingTenure = _calculateRemainingTenure(
            invoice.invoiceDate,
            invoice.dueDate,
            invoice.tenure
        );

        if (listedInfo.priceIsLocked) {
            return listedInfo.salePrice * userFractions;
        }

        return
            _calculatePrice(
                listedInfo.apr,
                invoice.fractions,
                userFractions,
                remainingTenure,
                invoice.dueAmount
            );
    }

    /**
     * @dev See {IGenericAsset-getPartialPrice}.
     */
    function getPartialPrice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 fractions
    ) external view returns (uint256) {
        uint256 userFractions = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        if (userFractions <= 0) {
            revert InvalidFraction();
        }

        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        ListedInfo memory listedInfo = _marketplace.getListedInfo(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 remainingTenure = _calculateRemainingTenure(
            invoice.invoiceDate,
            invoice.dueDate,
            invoice.tenure
        );

        if (listedInfo.priceIsLocked) {
            return listedInfo.salePrice * fractions;
        }

        if (fractions == 0) {
            return 0;
        } else {
            return
                _calculatePrice(
                    listedInfo.apr,
                    invoice.fractions,
                    fractions,
                    remainingTenure,
                    invoice.dueAmount
                );
        }
    }

    /**
     * @dev See {IInvoiceAsset-getAvailableReward}.
     */
    function getAvailableReward(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward) {
        uint256 _tradingRecord = _assetCollection.getTradingRecord(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 userFractions = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 purchaseDate = _purchaseDate[invoiceMainId][invoiceSubId];

        if (purchaseDate != 0) {
            uint256 payout = _getAvailablePayout(invoiceMainId, userFractions);
            if (payout == 0) {
                reward = 0;
            } else {
                reward = payout - (_tradingRecord * userFractions);
            }
        }
    }

    /**
     * @dev See {IInvoiceAsset-getRemainingReward}.
     */
    function getRemainingReward(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        uint256 userFractions = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );
        uint256 _tradingRecord = _assetCollection.getTradingRecord(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        if (_tradingRecord != 0) {
            reward =
                _calculateFormula(
                    invoice.dueAmount,
                    userFractions,
                    invoice.fractions
                ) -
                (_tradingRecord * userFractions);
        }
    }

    /**
     * @dev See {IInvoiceAsset-getTreasuryWallet}.
     */
    function getTreasuryWallet() external view returns (address) {
        return address(_treasuryWallet);
    }

    /**
     * @dev See {IInvoiceAsset-getInvoiceInfo}.
     */
    function getInvoiceInfo(
        uint256 invoiceMainId
    ) external view returns (InvoiceInfo memory) {
        return _invoiceInfo[invoiceMainId];
    }

    /**
     * @dev See {IInvoiceAsset-getCurrentSubId}.
     */
    function getCurrentSubId(
        uint256 invoiceMainId
    ) external view returns (uint256) {
        return _currentSubId[invoiceMainId];
    }

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @dev Wallet can be EOA or multisig
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        if (newTreasuryWallet == address(0)) {
            revert InvalidAddress();
        }

        emit TreasuryWalletSet(_treasuryWallet, newTreasuryWallet);
        _treasuryWallet = newTreasuryWallet;
    }

    /**
     * @dev Called in settleInvoice and batchSettleInvoice functions
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @param owner, address of the owner for settlement
     */
    function _settleInvoice(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address owner
    ) private {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        if (block.timestamp < invoice.dueDate) {
            revert DueDateNotPassed();
        }

        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        uint256 settlePrice = _getAvailablePayout(invoiceMainId, subBalanceOf);

        _assetCollection.burnAsset(
            owner,
            invoiceMainId,
            invoiceSubId,
            subBalanceOf
        );
        invoice.settlementToken.safeTransferFrom(
            _treasuryWallet,
            owner,
            settlePrice
        );
        if (_assetCollection.totalMainSupply(invoiceMainId) == 0) {
            delete _invoiceInfo[invoiceMainId];
        }

        emit InvoiceSettled(
            owner,
            invoiceMainId,
            invoiceSubId,
            settlePrice,
            address(invoice.settlementToken)
        );
    }

    /**
     * @dev Called in createInvoice and batchCreateInvoice functions
     * @param priceIsLocked, define if the price/apr is locked
     * @param invoiceInfo, related information for the invoice
     */
    function _createInvoice(
        bool priceIsLocked,
        InvoiceInfo calldata invoiceInfo
    ) private returns (uint256 invoiceMainId) {
        if (address(invoiceInfo.settlementToken) == address(0)) {
            revert InvalidAddress();
        }
        if (invoiceInfo.price == 0) {
            revert InvalidPrice();
        }
        // if (invoiceInfo.tenure == 0) {
        //     revert InvalidTenure();
        // }
        if (invoiceInfo.dueAmount == 0) {
            revert InvalidDueAmount();
        }
        // if (
        //     invoiceInfo.dueDate < block.timestamp ||
        //     invoiceInfo.dueDate < invoiceInfo.invoiceDate
        // ) {
        //     revert InvalidDueDate();
        // }
        if (invoiceInfo.fractions == 0) {
            revert InvalidFraction();
        }

        invoiceMainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    address(this),
                    address(this),
                    _nonce.useNonce(address(this))
                )
            )
        );
        if (_assetCollection.totalMainSupply(invoiceMainId) != 0) {
            revert InvoiceAlreadyCreated();
        }
        uint256 fractions = invoiceInfo.fractions;
        _invoiceInfo[invoiceMainId] = invoiceInfo;
        _assetCollection.setTradingRecord(
            address(this),
            invoiceMainId,
            0,
            invoiceInfo.price / fractions
        );

        uint256 apr = _calculateApr(
            invoiceInfo.price / fractions,
            fractions,
            fractions,
            invoiceInfo.tenure,
            invoiceInfo.dueAmount
        );

        _assetCollection.createAsset(
            address(this),
            invoiceMainId,
            0,
            fractions
        );
        _assetCollection.approve(
            address(_marketplace),
            invoiceMainId,
            0,
            fractions
        );
        _marketplace.list(
            invoiceMainId,
            0,
            ListedInfo(
                invoiceInfo.price / fractions,
                apr,
                fractions,
                1,
                priceIsLocked,
                invoiceInfo.settlementToken,
                address(this)
            )
        );
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param invoiceMainId, unique identifier of invoice
     * @param userFractions, the number of owned fractions
     */
    function _getAvailablePayout(
        uint256 invoiceMainId,
        uint256 userFractions
    ) private view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        uint256 totalFractions = invoice.fractions;

        if (invoice.invoiceDate == 0) {
            revert InvalidInvoiceDate();
        }
        if (totalFractions == 0) {
            revert InvalidFraction();
        }
        if (userFractions == 0) {
            return 0;
        }

        uint256 daysPassed = (
            block.timestamp > invoice.dueDate
                ? invoice.dueDate
                : block.timestamp
        ) - invoice.invoiceDate;

        daysPassed = daysPassed / 1 days;

        if (daysPassed > invoice.tenure) {
            daysPassed = invoice.tenure;
        }
        // if (daysPassed == 0) {
        //     return 0;
        // }

        // uint256 proratedDueAmount = (invoice.dueAmount * daysPassed) /
        //     invoice.tenure;

        uint256 proratedDueAmount = invoice.dueAmount;

        if (daysPassed != 0) {
            proratedDueAmount =
                (invoice.dueAmount * daysPassed) /
                invoice.tenure;
        }

        reward = _calculateFormula(
            proratedDueAmount,
            userFractions,
            totalFractions
        );
    }

    /**
     * @dev Calculates the apr for a given asset
     * @param invoiceDate the date invoice has been created at
     * @param dueDate the due date of the invoice
     * @param tenure the tenure of the invoice
     */
    function _calculateRemainingTenure(
        uint256 invoiceDate,
        uint256 dueDate,
        uint256 tenure
    ) private view returns (uint256) {
        uint256 remainingTenure = (
            block.timestamp > dueDate ? dueDate : block.timestamp
        ) - invoiceDate;

        remainingTenure = remainingTenure / 1 days;

        if (remainingTenure >= tenure) {
            remainingTenure = 0;
        } else {
            remainingTenure = tenure - remainingTenure;
        }

        return remainingTenure;
    }

    /**
     * @dev Calculates the rewards for a given asset
     * @param dueAmount is the due amount to pay of asset
     * @param userFractions is the user-owned fractions of the asset
     * @param totalFractions is the total fractions of the asset
     */
    function _calculateFormula(
        uint256 dueAmount,
        uint256 userFractions,
        uint256 totalFractions
    ) private pure returns (uint256) {
        return (dueAmount * userFractions) / totalFractions;
    }

    /**
     * @dev Calculates the apr for a given asset
     * @param price is the due amount to pay of asset
     * @param totalFractions the number of total fractions for this asset
     * @param userFractions the number of fractions owned for this asset
     * @param remainingTenure is the user-owned fractions of the asset
     * @param dueAmount is the total fractions of the asset
     */
    function _calculateApr(
        uint256 price,
        uint256 totalFractions,
        uint256 userFractions,
        uint256 remainingTenure,
        uint256 dueAmount
    ) private pure returns (uint256) {
        if (price <= 0) {
            revert InvalidPrice();
        }
        if (remainingTenure <= 0) {
            revert InvalidTenure();
        }
        if (dueAmount <= 0) {
            revert InvalidDueAmount();
        }
        if (userFractions <= 0) {
            revert InvalidFraction();
        }

        uint256 userDue = (dueAmount * userFractions) / totalFractions;
        uint256 userPaid = price * userFractions;

        return
            ((userDue - userPaid) * _PRECISION * 360) /
            (userPaid * remainingTenure);
    }

    /**
     * @dev Calculates the price for a given asset
     * @param apr is the due amount to pay of asset
     * @param totalFractions the number of total fractions for this asset
     * @param userFractions the number of fractions owned for this asset
     * @param remainingTenure is the user-owned fractions of the asset
     * @param dueAmount is the total fractions of the asset
     */
    function _calculatePrice(
        uint256 apr,
        uint256 totalFractions,
        uint256 userFractions,
        uint256 remainingTenure,
        uint256 dueAmount
    ) private pure returns (uint256) {
        if (apr <= 0) {
            revert InvalidApr();
        }
        if (remainingTenure <= 0) {
            revert InvalidTenure();
        }
        if (dueAmount <= 0) {
            revert InvalidDueAmount();
        }
        if (userFractions <= 0) {
            revert InvalidFraction();
        }

        return
            ((dueAmount * _PRECISION * 360) /
                (totalFractions * (apr * remainingTenure + _PRECISION * 360))) *
            userFractions;
    }
}
