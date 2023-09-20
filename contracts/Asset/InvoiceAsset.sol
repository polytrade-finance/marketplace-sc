// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { InvoiceInfo, IInvoiceAsset } from "contracts/Asset/interface/IInvoiceAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { IToken } from "contracts/Token/interface/IToken.sol";
import { IMarketplace } from "contracts/Marketplace/interface/IMarketplace.sol";

/**
 * @title The asset contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of asset and rewards distribution
 */
contract InvoiceAsset is Initializable, Context, AccessControl, IInvoiceAsset {
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    IBaseAsset private _assetCollection;
    IMarketplace private _marketplace;
    IToken private _stableToken;

    uint256 private constant _YEAR = 360 days;

    mapping(uint256 => mapping(uint256 => InvoiceInfo)) private _invoiceInfo;

    // Create a new role identifier for the asset originator
    bytes32 public constant ASSET_ORIGINATOR =
        0x6515eccc42cea4c6b51e4cf769f86c1580ce4efeb1d5bee305af7f36bbb6ce6e;

    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;

    /**
     * @dev Initializer for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     * @param tokenAddress_, Address of the ERC20 token address
     */
    function initialize(
        address marketplace_,
        address assetCollection_,
        address tokenAddress_
    ) external initializer {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        if (!marketplace_.supportsInterface(_MARKETPLACE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(tokenAddress_ != address(0), "Invalid address");

        _assetCollection = IBaseAsset(assetCollection_);
        _marketplace = IMarketplace(marketplace_);
        _stableToken = IToken(tokenAddress_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ASSET_ORIGINATOR, _msgSender());
    }

    /**
     * @dev See {IInvoiceAsset-createInvoice}.
     */
    function createInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        InvoiceInfo calldata invoiceInfo
    ) external onlyRole(ASSET_ORIGINATOR) {
        _createInvoice(owner, invoiceMainId, invoiceSubId, invoiceInfo);
    }

    /**
     * @dev See {IInvoiceAsset-batchCreateInvoice}.
     */
    function batchCreateInvoice(
        address[] calldata owners,
        uint256[] calldata invoiceMainIds,
        uint256[] calldata invoiceSubIds,
        InvoiceInfo[] calldata invoiceInfos
    ) external onlyRole(ASSET_ORIGINATOR) {
        uint256 length = owners.length;
        require(
            invoiceMainIds.length == length &&
                length == invoiceInfos.length &&
                length == invoiceSubIds.length,
            "No array parity"
        );

        for (uint256 i = 0; i < length; ) {
            _createInvoice(
                owners[i],
                invoiceMainIds[i],
                invoiceSubIds[i],
                invoiceInfos[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IInvoiceAsset-settleInvoice}.
     */
    function settleInvoice(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address owner
    ) external onlyRole(ASSET_ORIGINATOR) {
        _claimReward(invoiceMainId, invoiceSubId, owner);
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
        require(
            owners.length == length && length == invoiceSubIds.length,
            "No array parity"
        );
        for (uint256 i = 0; i < length; ) {
            _claimReward(invoiceMainIds[i], invoiceSubIds[i], owners[i]);
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

        _invoiceInfo[invoiceMainId][invoiceSubId].fractions = totalSubSupply;

        if (totalSubSupply == 0) {
            delete _invoiceInfo[invoiceMainId][invoiceSubId];
        }
    }

    function getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256) {
        return _getAvailableReward(invoiceMainId, invoiceSubId);
    }

    function getRemainingReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId][invoiceSubId];
        uint256 purchaseDate = _assetCollection
            .getAssetInfo(invoiceMainId, invoiceSubId)
            .purchaseDate;
        uint256 tenure;

        if (purchaseDate != 0) {
            tenure = invoice.dueDate - purchaseDate;
        } else if (invoice.price != 0) {
            tenure =
                invoice.dueDate -
                (
                    block.timestamp > invoice.dueDate
                        ? invoice.dueDate
                        : block.timestamp
                );
        }
        reward = _calculateFormula(invoice.price, tenure, invoice.rewardApr);
    }

    function getInvoiceInfo(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (InvoiceInfo memory info) {
        info = _invoiceInfo[invoiceMainId][invoiceSubId];
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
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId][invoiceSubId];
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        require(subBalanceOf != 0, "Not enough balance");
        require(block.timestamp > invoice.dueDate, "Due date not passed");

        uint256 settlePrice = (invoice.price * subBalanceOf) /
            invoice.fractions;
        _assetCollection.burnAsset(
            owner,
            invoiceMainId,
            invoiceSubId,
            subBalanceOf
        );
        _stableToken.safeTransferFrom(
            _marketplace.getTreasuryWallet(),
            owner,
            settlePrice
        );
        if (_assetCollection.totalSubSupply(invoiceMainId, invoiceSubId) == 0) {
            delete _invoiceInfo[invoiceMainId][invoiceSubId];
        }

        emit InvoiceSettled(owner, invoiceMainId, invoiceSubId, settlePrice);
    }

    /**
     * @dev Called in createInvoice and batchCreateInvoice functions
     * @param owner, initial owner of invoice
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @param invoiceInfo, related information for the invoice
     */
    function _createInvoice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        InvoiceInfo calldata invoiceInfo
    ) private {
        require(
            _assetCollection.totalSubSupply(invoiceMainId, invoiceSubId) == 0,
            "Invoice already created"
        );

        _invoiceInfo[invoiceMainId][invoiceSubId] = invoiceInfo;
        _assetCollection.createAsset(
            owner,
            invoiceMainId,
            invoiceSubId,
            invoiceInfo.fractions
        );
    }

    /**
     * @dev Transfers rewards to owner and updates purchaseDate
     * @param invoiceMainId, invoice unique identifier
     * @param invoiceSubId, invoice unique identifier
     * @param receiver, address of receiver reward
     */

    function _claimReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        address receiver
    ) private {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId][invoiceSubId];
        require(invoice.dueDate != 0, "Invalid invoice id");

        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            receiver,
            invoiceMainId,
            invoiceSubId
        );
        uint256 reward = (_getAvailableReward(invoiceMainId, invoiceSubId) *
            subBalanceOf) / invoice.fractions;

        _stableToken.safeTransferFrom(
            _marketplace.getTreasuryWallet(),
            receiver,
            reward
        );

        emit RewardsClaimed(receiver, invoiceMainId, invoiceSubId, reward);
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     */
    function _getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) private view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId][invoiceSubId];
        uint256 purchaseDate = _assetCollection
            .getAssetInfo(invoiceMainId, invoiceSubId)
            .purchaseDate;

        if (purchaseDate != 0) {
            uint256 tenure = (
                block.timestamp > invoice.dueDate
                    ? invoice.dueDate
                    : block.timestamp
            ) - purchaseDate;

            reward = _calculateFormula(
                invoice.price,
                tenure,
                invoice.rewardApr
            );
        }
    }

    /**
     * @dev Calculates the rewards for a given asset
     * @param price is the price of asset
     * @param tenure is the duration from last updated rewards
     * @param apr is the annual percentage rate of rewards for assets
     */
    function _calculateFormula(
        uint256 price,
        uint256 tenure,
        uint256 apr
    ) private pure returns (uint256) {
        return ((price * tenure * apr) / 1e4) / _YEAR;
    }
}
