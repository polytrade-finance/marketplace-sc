// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { InvoiceInfo, IInvoiceAsset, IToken } from "contracts/Asset/interface/IInvoiceAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { ListedInfo, IMarketplace } from "contracts/Marketplace/interface/IMarketplace.sol";
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
    IMarketplace private _marketplace;
    Counters.Counter private _nonce;

    address private _treasuryWallet;

    // solhint-disable-next-line
    uint256 private CHAIN_ID;

    uint256 private constant _YEAR = 360 days;

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
        InvoiceInfo calldata invoiceInfo
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256) {
        return _createInvoice(invoiceInfo);
    }

    /**
     * @dev See {IInvoiceAsset-batchCreateInvoice}.
     */
    function batchCreateInvoice(
        InvoiceInfo[] calldata invoiceInfos
    ) external onlyRole(ASSET_ORIGINATOR) returns (uint256[] memory) {
        uint256 length = invoiceInfos.length;
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _createInvoice(invoiceInfos[i]);

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
        if (owners.length != length || invoiceSubIds.length != length) {
            revert NoArrayParity();
        }

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

        _invoiceInfo[invoiceMainId].fractions = totalSubSupply;

        if (totalSubSupply == 0) {
            delete _invoiceInfo[invoiceMainId];
        }
    }

    /**
     * @dev See {IInvoiceAsset-onSubIdCreation}.
     */
    function onSubIdCreation(
        address owner,
        uint256 mainId,
        uint256 fractions
    ) external onlyRole(MARKETPLACE_ROLE) {
        _currentSubId[mainId] += 1;
        _purchaseDate[mainId][_currentSubId[mainId]] = block.timestamp;

        _assetCollection.burnAsset(
            _assetCollection.getAssetInfo(mainId, 0).initialOwner,
            mainId,
            0,
            fractions
        );
        _assetCollection.createAsset(
            owner,
            mainId,
            _currentSubId[mainId],
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
     * @dev See {IInvoiceAsset-getAvailableReward}.
     */
    function getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        if (invoice.fractions != 0) {
            reward =
                (_getAvailableReward(
                    invoiceMainId,
                    invoiceSubId,
                    block.timestamp > invoice.dueDate
                        ? invoice.dueDate
                        : block.timestamp
                ) *
                    _assetCollection.totalSubSupply(
                        invoiceMainId,
                        invoiceSubId
                    )) /
                invoice.fractions;
        }
    }

    /**
     * @dev See {IInvoiceAsset-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];

        if (invoice.fractions != 0) {
            uint256 purchaseDate = _purchaseDate[invoiceMainId][invoiceSubId];
            uint256 tenure;
            if (purchaseDate != 0) {
                tenure = invoice.dueDate - purchaseDate;
            } else {
                tenure =
                    invoice.dueDate -
                    (
                        block.timestamp > invoice.dueDate
                            ? invoice.dueDate
                            : block.timestamp
                    );
            }
            reward =
                (_calculateFormula(invoice.price, tenure, invoice.rewardApr) *
                    _assetCollection.totalSubSupply(
                        invoiceMainId,
                        invoiceSubId
                    )) /
                invoice.fractions;
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
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            invoiceMainId,
            invoiceSubId
        );

        if (subBalanceOf == 0) {
            revert NotEnoughBalance();
        }
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        if (block.timestamp < invoice.dueDate) {
            revert DueDateNotPassed();
        }

        uint256 settlePrice = (invoice.price * subBalanceOf) /
            invoice.fractions;
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
     * @param invoiceInfo, related information for the invoice
     */
    function _createInvoice(
        InvoiceInfo calldata invoiceInfo
    ) private returns (uint256 invoiceMainId) {
        if (address(invoiceInfo.settlementToken) == address(0)) {
            revert InvalidAddress();
        }
        if (invoiceInfo.price == 0) {
            revert InvalidPrice();
        }
        if (invoiceInfo.dueDate < block.timestamp) {
            revert InvalidDueDate();
        }
        if (invoiceInfo.fractions == 0) {
            revert InvalidFraction();
        }
        if (invoiceInfo.rewardApr == 0) {
            revert InvalidRewardApr();
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
                fractions,
                1,
                invoiceInfo.settlementToken
            )
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
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        if (invoice.dueDate == 0) {
            revert InvalidInvoiceId();
        }
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            receiver,
            invoiceMainId,
            invoiceSubId
        );
        uint256 reward = (_getAvailableReward(
            invoiceMainId,
            invoiceSubId,
            invoice.dueDate
        ) * subBalanceOf) / invoice.fractions;

        invoice.settlementToken.safeTransferFrom(
            _treasuryWallet,
            receiver,
            reward
        );

        emit RewardsClaimed(
            receiver,
            invoiceMainId,
            invoiceSubId,
            reward,
            address(invoice.settlementToken)
        );
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param invoiceMainId, unique identifier of invoice
     */
    function _getAvailableReward(
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 endDate
    ) private view returns (uint256 reward) {
        InvoiceInfo memory invoice = _invoiceInfo[invoiceMainId];
        uint256 purchaseDate = _purchaseDate[invoiceMainId][invoiceSubId];

        if (purchaseDate != 0) {
            reward = _calculateFormula(
                invoice.price,
                endDate - purchaseDate,
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
