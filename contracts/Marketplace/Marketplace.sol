// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { EIP712Upgradeable } from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ListedInfo, IMarketplace, IToken } from "contracts/Marketplace/interface/IMarketplace.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { IInvoiceAsset } from "contracts/Asset/interface/IInvoiceAsset.sol";
import { IFeeManager } from "contracts/Marketplace/interface/IFeeManager.sol";
import { Counters } from "contracts/lib/Counters.sol";

/**
 * @title The common marketplace for the assets
 * @author Polytrade.Finance
 * @dev Implementation of all assets trading operations
 */
contract Marketplace is
    Initializable,
    Context,
    ERC165,
    EIP712Upgradeable,
    AccessControl,
    ReentrancyGuard,
    IMarketplace
{
    using SafeERC20 for IToken;
    using ERC165Checker for address;
    using Counters for Counters.Counter;

    IBaseAsset private _assetCollection;
    IFeeManager private _feeManager;
    Counters.Counter private _nonce;

    mapping(uint256 => mapping(uint256 => mapping(address => ListedInfo)))
        private _listedInfo;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "CounterOffer(",
                "address owner,",
                "address offeror,",
                "uint256 offerPrice,",
                "uint256 mainId,",
                "uint256 subId,",
                "uint256 fractionsToBuy,",
                "uint256 nonce,",
                "uint256 deadline",
                ")"
            )
        );
    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;

    bytes4 private constant _FEEMANAGER_INTERFACE_ID =
        type(IFeeManager).interfaceId;

    /**
     * @dev Initializer for the main Marketplace
     * @param assetCollection_, Address of the asset collection used in the marketplace
     * @param feeManager_, Address of the fee manager
     */
    function initialize(
        address assetCollection_,
        address feeManager_
    ) external initializer {
        __EIP712_init("Polytrade", "2.3");
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        _assetCollection = IBaseAsset(assetCollection_);

        _setFeeManager(feeManager_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IMarketplace-list}.
     */
    function list(
        uint256 mainId,
        uint256 subId,
        ListedInfo calldata listedInfo
    ) external {
        _list(mainId, subId, listedInfo);
    }

    /**
     * @dev See {IMarketplace-batchList}.
     */
    function batchList(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        ListedInfo[] calldata listedInfos
    ) external {
        uint256 length = subIds.length;
        require(
            mainIds.length == length && length == listedInfos.length,
            "No array parity"
        );
        for (uint256 i = 0; i < length; ) {
            _list(mainIds[i], subIds[i], listedInfos[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-counterOffer}.
     */
    function counterOffer(
        address owner,
        address offeror,
        uint256 offerPrice,
        uint256 mainId,
        uint256 subId,
        uint256 fractionsToBuy,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        {
            require(block.timestamp <= deadline, "Offer expired");
            require(offeror == _msgSender(), "You are not the offeror");
            uint256 nonce = _nonce.useNonce(owner);
            bytes32 offerHash = keccak256(
                abi.encode(
                    _OFFER_TYPEHASH,
                    owner,
                    offeror,
                    offerPrice,
                    mainId,
                    subId,
                    fractionsToBuy,
                    nonce,
                    deadline
                )
            );

            bytes32 hash = _hashTypedDataV4(offerHash);
            address signer = ECDSA.recover(hash, v, r, s);

            require(signer == owner, "Invalid signature");
        }
        {
            _buy(mainId, subId, offerPrice, fractionsToBuy, owner);
        }
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(
        uint256 mainId,
        uint256 subId,
        uint256 fractionToBuy,
        address owner
    ) external {
        _buy(
            mainId,
            subId,
            _listedInfo[mainId][subId][owner].salePrice,
            fractionToBuy,
            owner
        );
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata fractionsToBuy,
        address[] calldata owners
    ) external {
        uint256 length = subIds.length;
        require(
            mainIds.length == length &&
                length == fractionsToBuy.length &&
                length == owners.length,
            "No array parity"
        );
        for (uint256 i = 0; i < length; ) {
            _buy(
                mainIds[i],
                subIds[i],
                _listedInfo[mainIds[i]][subIds[i]][owners[i]].salePrice,
                fractionsToBuy[i],
                owners[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-setFeeManager}.
     */
    function setFeeManager(
        address newFeeManager
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeManager(newFeeManager);
    }

    /**
     * @dev See {IMarketplace-getFeeManager}.
     */
    function getFeeManager() external view returns (address) {
        return address(_feeManager);
    }

    /**
     * @dev See {IMarketplace-getAssetCollection}.
     */
    function getAssetCollection() external view returns (address) {
        return address(_assetCollection);
    }

    /**
     * @dev See {IMarketplace-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev See {IMarketplace-getNonce}.
     */
    function getNonce(address owner) external view virtual returns (uint256) {
        return _nonce.current(owner);
    }

    /**
     * @dev See {IMarketplace-getPropertyInfo}.
     */
    function getListedInfo(
        address owner,
        uint256 assetMainId,
        uint256 assetSubId
    ) external view returns (ListedInfo memory) {
        return _listedInfo[assetMainId][assetSubId][owner];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(IMarketplace).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev List an asset based on main id and sub id
     * @dev Checks and validate listed fraction to be greater than min fraction
     * @dev Validates if listed fractions is less than owner current balance
     * @param mainId, unique identifier of the asset
     * @param subId, unique identifier of the asset
     * @param listedInfo, information of listed asset including salePrice, listedFraction, minFraction and token of sale
     */
    function _list(
        uint256 mainId,
        uint256 subId,
        ListedInfo calldata listedInfo
    ) private {
        require(address(listedInfo.token) != address(0), "Invalid address");
        require(listedInfo.minFraction != 0, "Min. fraction can not be zero");
        require(
            listedInfo.listedFractions >= listedInfo.minFraction,
            "Min. fraction > Fraction to list"
        );
        require(listedInfo.salePrice != 0, "Sale price can not be zero");

        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            _msgSender(),
            mainId,
            subId
        );
        require(
            subBalanceOf >= listedInfo.listedFractions,
            "Fraction to list > Balance"
        );

        _listedInfo[mainId][subId][_msgSender()] = listedInfo;

        emit AssetListed(_msgSender(), mainId, subId, listedInfo);
    }

    /**
     * @dev Safe transfer asset to marketplace and transfer the price to the prev owner
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Transfer buying fee or initial fee to fee wallet based on asset status
     * @param mainId, unique identifier of the asset
     * @param subId, unique identifier of the asset
     * @param salePrice, sale price for buying specific fraction of asset
     * @param fractionToBuy, number of fractions to buy from owner address
     * @param owner, address of owner of the fraction of asset
     */
    function _buy(
        uint256 mainId,
        uint256 subId,
        uint256 salePrice,
        uint256 fractionToBuy,
        address owner
    ) private nonReentrant {
        ListedInfo memory listedInfo = _listedInfo[mainId][subId][owner];

        require(
            fractionToBuy >= listedInfo.minFraction,
            "Fraction to buy < Min. fraction"
        );
        require(
            listedInfo.listedFractions >= fractionToBuy,
            "Listed fractions < Fraction to buy"
        );
        require(
            fractionToBuy <=
                _assetCollection.subBalanceOf(owner, mainId, subId),
            "Not enough balance to buy"
        );

        address receiver = owner;
        uint256 payPrice = (salePrice * fractionToBuy) / 1e2;
        uint256 fee = _assetCollection
            .getAssetInfo(mainId, subId)
            .initialOwner != owner
            ? _feeManager.getBuyingFee(mainId, subId)
            : _feeManager.getInitialFee(mainId, subId);
        fee = (payPrice * fee) / 1e4;

        if (listedInfo.listedFractions == fractionToBuy) {
            delete _listedInfo[mainId][subId][owner];
        } else {
            _listedInfo[mainId][subId][owner].listedFractions =
                listedInfo.listedFractions -
                fractionToBuy;
        }

        if (subId == 0) {
            receiver = IInvoiceAsset(owner).getTreasuryWallet();
            IInvoiceAsset(owner).onSubIdCreation(
                _msgSender(),
                mainId,
                fractionToBuy
            );
        } else {
            _assetCollection.safeTransferFrom(
                owner,
                _msgSender(),
                mainId,
                subId,
                fractionToBuy,
                ""
            );
        }

        listedInfo.token.safeTransferFrom(_msgSender(), receiver, payPrice);
        listedInfo.token.safeTransferFrom(
            _msgSender(),
            _feeManager.getFeeWallet(),
            fee
        );
        emit AssetBought(
            owner,
            _msgSender(),
            mainId,
            subId,
            salePrice,
            payPrice,
            fractionToBuy,
            address(listedInfo.token)
        );
    }

    /**
     * @notice Allows to set a new address for the fee manager.
     * @dev Fee manager should support IFeeManager interface
     * @param newFeeManager, Address of the new fee manager
     */
    function _setFeeManager(address newFeeManager) private {
        if (!newFeeManager.supportsInterface(_FEEMANAGER_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        emit FeeManagerSet(address(_feeManager), newFeeManager);
        _feeManager = IFeeManager(newFeeManager);
    }
}
