// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { InvoiceInfo, IInvoiceAsset, IToken } from "contracts/Asset/interface/IInvoiceAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { IToken } from "contracts/Token/interface/IToken.sol";
import { Counters } from "contracts/lib/Counters.sol";

/**
 * @title The asset contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of asset and rewards distribution
 */
contract InvoiceAsset is Initializable, Context, AccessControl, IInvoiceAsset {
    using SafeERC20 for IToken;
    using ERC165Checker for address;
    using Counters for Counters.Counter;

    IBaseAsset private _assetCollection;
    Counters.Counter private _nonce;

    address private _treasuryWallet;

    // solhint-disable-next-line
    uint256 private CHAIN_ID;

    uint256 private constant _YEAR = 360 days;

    mapping(uint256 => InvoiceInfo) private _invoiceInfo;

    // Create a new role identifier for the asset originator
    bytes32 public constant ASSET_ORIGINATOR =
        0x6515eccc42cea4c6b51e4cf769f86c1580ce4efeb1d5bee305af7f36bbb6ce6e;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;

    /**
     * @dev Initializer for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     * @param treasuryWallet_, Address of the treasury wallet
     */
    function initialize(
        address assetCollection_,
        address treasuryWallet_
    ) external initializer {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        _assetCollection = IBaseAsset(assetCollection_);
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
        address owner,
        InvoiceInfo calldata invoiceInfo
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256) {
        return _createInvoice(owner, invoiceInfo);
    }

    /**
     * @dev See {IInvoiceAsset-batchCreateInvoice}.
     */
    function batchCreateInvoice(
        address[] calldata owners,
        InvoiceInfo[] calldata invoiceInfos
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256[] memory) {
        uint256 length = owners.length;
        require(length == invoiceInfos.length, "No array parity");
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _createInvoice(owners[i], invoiceInfos[i]);

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
        address owner
    ) external onlyRole(ASSET_ORIGINATOR) {
        _claimReward(invoiceMainId, owner);
        _settleInvoice(invoiceMainId, owner);
    }

    /**
     * @dev See {IInvoiceAsset-batchSettleInvoice}.
     */
    function batchSettleInvoice(
        uint256[] calldata invoiceMainIds,
        address[] calldata owners
    ) external onlyRole(ASSET_ORIGINATOR) {
        uint256 length = invoiceMainIds.length;
        require(owners.length == length, "No array parity");
        for (uint256 i = 0; i < length; ) {
            _claimReward(invoiceMainIds[i], owners[i]);
            _settleInvoice(invoiceMainIds[i], owners[i]);

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
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetCollection.burnAsset(owner, invoiceMainId, 1, amount);
        uint256 totalSubSupply = _assetCollection.totalSubSupply(
            invoiceMainId,
            1
        );

        _invoiceInfo[invoiceMainId].fractions = totalSubSupply;

        if (totalSubSupply == 0) {
            delete _invoiceInfo[invoiceMainId];
        }
    }

    /**
     * @dev See {IInvoiceAsset-getNonce}.
     */
    function getNonce(address account) external view returns (uint256) {
        return _nonce.current(account);
    }

    /**
     * @dev See {IInvoiceAsset-getAvailableReward}.
     */
    function getAvailableReward(
        uint256 invoiceMainId
    ) external view returns (uint256) {
        return _getAvailableReward(invoiceMainId);
    }

    /**
     * @dev See {IInvoiceAsset-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 invoiceMainId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        uint256 purchaseDate = _assetCollection
            .getAssetInfo(invoiceMainId, 1)
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
    ) external view returns (InvoiceInfo memory info) {
        info = _invoiceInfo[invoiceMainId];
    }

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @dev Wallet can be EOA or multisig
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        require(newTreasuryWallet != address(0), "Invalid wallet address");

        emit TreasuryWalletSet(_treasuryWallet, newTreasuryWallet);
        _treasuryWallet = newTreasuryWallet;
    }

    /**
     * @dev Called in settleInvoice and batchSettleInvoice functions
     * @param invoiceMainId, unique identifier of invoice
     * @param owner, address of the owner for settlement
     */
    function _settleInvoice(uint256 invoiceMainId, address owner) private {
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            1
        );

        require(subBalanceOf != 0, "Not enough balance");
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        require(block.timestamp > invoice.dueDate, "Due date not passed");

        uint256 settlePrice = (invoice.price * subBalanceOf) /
            invoice.fractions;
        _assetCollection.burnAsset(owner, invoiceMainId, 1, subBalanceOf);
        invoice.settlementToken.safeTransferFrom(
            _treasuryWallet,
            owner,
            settlePrice
        );
        if (_assetCollection.totalSubSupply(invoiceMainId, 1) == 0) {
            delete _invoiceInfo[invoiceMainId];
        }

        emit InvoiceSettled(
            owner,
            invoiceMainId,
            settlePrice,
            address(invoice.settlementToken)
        );
    }

    /**
     * @dev Called in createInvoice and batchCreateInvoice functions
     * @param owner, initial owner of invoice
     * @param invoiceInfo, related information for the invoice
     */
    function _createInvoice(
        address owner,
        InvoiceInfo calldata invoiceInfo
    ) private returns (uint256 invoiceMainId) {
        require(
            address(invoiceInfo.settlementToken) != address(0),
            "Invalid address"
        );
        invoiceMainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    address(this),
                    _nonce.useNonce(owner)
                )
            )
        );
        require(
            _assetCollection.totalSubSupply(invoiceMainId, 1) == 0,
            "Invoice already created"
        );

        _invoiceInfo[invoiceMainId] = invoiceInfo;
        _assetCollection.createAsset(
            owner,
            invoiceMainId,
            1,
            invoiceInfo.fractions
        );
    }

    /**
     * @dev Transfers rewards to owner and updates purchaseDate
     * @param invoiceMainId, invoice unique identifier
     * @param receiver, address of receiver reward
     */
    function _claimReward(uint256 invoiceMainId, address receiver) private {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        require(invoice.dueDate != 0, "Invalid invoice id");

        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            receiver,
            invoiceMainId,
            1
        );
        uint256 reward = (_getAvailableReward(invoiceMainId) * subBalanceOf) /
            invoice.fractions;

        invoice.settlementToken.safeTransferFrom(
            _treasuryWallet,
            receiver,
            reward
        );

        emit RewardsClaimed(
            receiver,
            invoiceMainId,
            reward,
            address(invoice.settlementToken)
        );
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param invoiceMainId, unique identifier of invoice
     */
    function _getAvailableReward(
        uint256 invoiceMainId
    ) private view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        uint256 purchaseDate = _assetCollection
            .getAssetInfo(invoiceMainId, 1)
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
