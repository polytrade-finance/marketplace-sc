// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {EIP712Upgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC165Checker} from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ListedInfo, IMarketplace} from "contracts/Marketplace/interface/IMarketplace.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IToken} from "contracts/Token/interface/IToken.sol";
import {AssetInfo, IBaseAsset} from "contracts/Asset/interface/IBaseAsset.sol";

/**
 * @title The common marketplace for the assets
 * @author Polytrade.Finance
 * @dev Implementation of all assets trading operations
 */
contract Marketplace is Initializable, Context, EIP712Upgradeable, AccessControl, IMarketplace {
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    uint256 private _initialFee;
    uint256 private _buyingFee;

    IBaseAsset private _assetCollection;
    IToken private _stableToken;

    address private _feeWallet;

    mapping(uint256 => mapping(uint256 => mapping(address => ListedInfo))) private _listedInfo;
    mapping(address => uint256) private _currentNonce;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _OFFER_TYPEHASH = keccak256(
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

    /**
     * @dev Initializer for the main Marketplace
     * @param assetCollection_, Address of the asset collection used in the marketplace
     * @param tokenAddress_, Address of the ERC20 token address
     * @param feeWallet_, Address of the fee wallet
     */
    function initialize(address assetCollection_, address tokenAddress_, address feeWallet_) external initializer {
        __EIP712_init("Polytrade", "2.3");
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        require(tokenAddress_ != address(0), "Invalid address");

        _assetCollection = IBaseAsset(assetCollection_);
        _stableToken = IToken(tokenAddress_);

        _setFeeWallet(feeWallet_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IMarketplace-list}.
     */
    function list(uint256 mainId, uint256 subId, uint256 salePrice, uint256 listedFractions, uint256 minFraction)
        external
    {
        uint256 subBalanceOf = _assetCollection.subBalanceOf(_msgSender(), mainId, subId);
        require(minFraction != 0, "Min. fraction can not be zero");
        require(listedFractions >= minFraction, "Min. fraction > Fractions");
        require(subBalanceOf >= listedFractions, "Fractions > Balance");

        _listedInfo[mainId][subId][_msgSender()] = ListedInfo(salePrice, listedFractions, minFraction);

        emit AssetListed(_msgSender(), mainId, subId, salePrice, listedFractions, minFraction);
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
            uint256 nonce = _useNonce(owner);
            bytes32 offerHash = keccak256(
                abi.encode(_OFFER_TYPEHASH, owner, offeror, offerPrice, mainId, subId, fractionsToBuy, nonce, deadline)
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
    function buy(uint256 mainId, uint256 subId, uint256 fractionToBuy, address owner) external {
        _buy(mainId, subId, _listedInfo[mainId][subId][owner].salePrice, fractionToBuy, owner);
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
            mainIds.length == length && length == fractionsToBuy.length && length == owners.length, "No array parity"
        );
        for (uint256 i = 0; i < length;) {
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
     * @dev See {IMarketplace-setInitialFee}.
     */
    function setInitialFee(uint256 initialFee_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = _initialFee;
        _initialFee = initialFee_;

        emit InitialFeeSet(oldFee, _initialFee);
    }

    /**
     * @dev See {IMarketplace-setBuyingFee}.
     */
    function setBuyingFee(uint256 buyingFee_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = _buyingFee;
        _buyingFee = buyingFee_;

        emit BuyingFeeSet(oldFee, _buyingFee);
    }

    /**
     * @dev See {IMarketplace-setFeeWallet}.
     */
    function setFeeWallet(address newFeeWallet) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeWallet(newFeeWallet);
    }

    /**
     * @dev See {IMarketplace-getAssetCollection}.
     */
    function getAssetCollection() external view returns (address) {
        return address(_assetCollection);
    }

    /**
     * @dev See {IMarketplace-getStableToken}.
     */
    function getStableToken() external view returns (address) {
        return address(_stableToken);
    }

    /**
     * @dev See {IMarketplace-getFeeWallet}.
     */
    function getFeeWallet() external view returns (address) {
        return address(_feeWallet);
    }

    /**
     * @dev See {IMarketplace-DOMAIN_SEPARATOR}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view virtual returns (bytes32) {
        return _domainSeparatorV4();
    }

    /**
     * @dev See {IMarketplace-nonces}.
     */
    function nonces(address owner) external view virtual returns (uint256) {
        return _currentNonce[owner];
    }

    /**
     * @dev See {IMarketplace-getInitialFee}.
     */
    function getInitialFee() external view returns (uint256) {
        return _initialFee;
    }

    /**
     * @dev See {IMarketplace-getBuyingFee}.
     */
    function getBuyingFee() external view returns (uint256) {
        return _buyingFee;
    }

    /**
     * @dev See {IMarketplace-getPropertyInfo}.
     */
    function getListedInfo(address owner, uint256 assetMainId, uint256 assetSubId)
        external
        view
        returns (ListedInfo memory)
    {
        return _listedInfo[assetMainId][assetSubId][owner];
    }

    /**
     * @dev "Consume a nonce": return the current value and increment
     */
    function _useNonce(address owner) internal virtual returns (uint256 current) {
        current = _currentNonce[owner];
        _currentNonce[owner]++;
    }

    /**
     * @notice Allows to set a new address for the fee wallet.
     * @dev Wallet can be EOA or multisig
     * @param newFeeWallet, Address of the new fee wallet
     */
    function _setFeeWallet(address newFeeWallet) private {
        require(newFeeWallet != address(0), "Invalid wallet address");

        address oldFeeWallet = address(_feeWallet);
        _feeWallet = newFeeWallet;

        emit FeeWalletSet(oldFeeWallet, newFeeWallet);
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
    function _buy(uint256 mainId, uint256 subId, uint256 salePrice, uint256 fractionToBuy, address owner) private {

        AssetInfo memory assetInfo = _assetCollection.getAssetInfo(mainId, subId);

        ListedInfo memory listedInfo = _listedInfo[mainId][subId][owner];

        require(fractionToBuy >= listedInfo.minFraction, "Fraction to buy < Min. fraction");
        require(listedInfo.listedFractions >= fractionToBuy, "Listed fractions < Fraction to buy");
        require(fractionToBuy <= _assetCollection.subBalanceOf(owner, mainId, subId), "Not enough balance to buy");
        // require(salePrice != 0, "Asset is not listed");

        uint256 payPrice = (salePrice * fractionToBuy) / 1e4;
        uint256 fee = assetInfo.initialOwner != owner ? _buyingFee : _initialFee;
        fee = (payPrice * fee) / 1e4;

        if (assetInfo.purchaseDate == 0) {
            _assetCollection.updatePurchaseDate(mainId, subId);
        }
        if (listedInfo.listedFractions == fractionToBuy) {
            delete _listedInfo[mainId][subId][owner];
        } else {
            _listedInfo[mainId][subId][owner].listedFractions = listedInfo.listedFractions - fractionToBuy;
        }

        _assetCollection.safeTransferFrom(owner, _msgSender(), mainId, subId, fractionToBuy, "");
        _stableToken.safeTransferFrom(_msgSender(), owner, payPrice);
        _stableToken.safeTransferFrom(_msgSender(), _feeWallet, fee);
        emit AssetBought(owner, _msgSender(), mainId, subId, salePrice, payPrice, fractionToBuy);
    }
}
