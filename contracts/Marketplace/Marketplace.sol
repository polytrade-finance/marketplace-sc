// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "dual-layer-token/contracts/DLT/interfaces/IDLTReceiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "contracts/Token//interface/IToken.sol";
import "contracts/Asset/interface/IAsset.sol";

/**
 * @title The common marketplace for the assets
 * @author Polytrade.Finance
 * @dev Implementation of all assets trading operations
 */
    Context,
    ERC165,
    EIP712,
    AccessControl,
    IMarketplace,
    IERC721Receiver,
    IERC1155Receiver,
    IDLTReceiver
{
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    uint256 private constant _YEAR = 365 days;

    uint256 private _initialFee;
    uint256 private _buyingFee;

    IAsset private immutable _assetCollection;
    IToken private immutable _stableToken;

    address private _treasuryWallet;
    address private _feeWallet;

    /**
     * @dev Mapping will be indexing the AssetInfo for each asset collection by its id
     */
    mapping(address => mapping(uint256 => AssetInfo)) private _assets;
    mapping(address => uint256) private _currentNonce;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "CounterOffer(",
                "address owner,",
                "address offeror,",
                "uint256 offerPrice,",
                "uint256 assetId,",
                "uint256 nonce,",
                "uint256 deadline",
                ")"
            )
        );
    bytes4 private constant _ASSET_INTERFACE_ID = type(IAsset).interfaceId;
    bytes4 private constant _ERC721_INTERFACE_ID = type(IERC721).interfaceId;
    bytes4 private constant _ERC1155_INTERFACE_ID = type(IERC1155).interfaceId;

    /**
     * @dev Constructor for the main Marketplace
     * @param assetCollection_, Address of the asset collection used in the marketplace
     * @param tokenAddress_, Address of the ERC20 token address
     * @param treasuryWallet_, Address of the treasury wallet
     * @param feeWallet_, Address of the fee wallet
     */
    constructor(
        address assetCollection_,
        address tokenAddress_,
        address treasuryWallet_,
        address feeWallet_
    ) EIP712("Polytrade", "2.1") {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(tokenAddress_ != address(0), "Invalid address");

        _assetCollection = IAsset(assetCollection_);
        _stableToken = IToken(tokenAddress_);

        _setTreasuryWallet(treasuryWallet_);
        _setFeeWallet(feeWallet_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IMarketplace-list721Asset}.
     */
    function list721Asset(
        address collection,
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!collection.supportsInterface(_ERC721_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(
            IERC721(collection).ownerOf(assetId) == owner,
            "owner does not own the asset"
        );
        require(owner != address(0), "Invalid owner address");

        _listAsset(collection, owner, assetId, price, apr, dueDate);
    }

    /**
     * @dev See {IMarketplace-list1155Asset}.
     */
    function list1155Asset(
        address collection,
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (!collection.supportsInterface(_ERC1155_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(
            IERC1155(collection).balanceOf(owner, assetId) != 0,
            "owner does not own the asset"
        );
        require(owner != address(0), "Invalid owner address");

        _listAsset(collection, owner, assetId, price, apr, dueDate);
    }

    /**
     * @dev See {IMarketplace-createAsset}.
     */
    function createAsset(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createAsset(owner, assetId, price, apr, dueDate);
    }

    /**
     * @dev See {IMarketplace-createAsset}.
     */
    function burnAsset(
        address owner,
        uint256 assetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetCollection.burnAsset(owner, assetId);
    }

    /**
     * @dev See {IMarketplace-batchCreateAsset}.
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            owners.length == mainIds.length &&
                owners.length == prices.length &&
                owners.length == dueDates.length &&
                owners.length == aprs.length,
            "No array parity"
        );

        for (uint256 i = 0; i < mainIds.length; ) {
            _assetCollection.createAsset(
                owners[i],
                mainIds[i],
                prices[i],
                aprs[i],
                dueDates[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-settleAsset}.
     */
    function settleAsset(
        address collection,
        uint256 assetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AssetInfo memory asset = _assets[collection][assetId];
        require(asset.owner != address(0), "Invalid asset id");
        require(block.timestamp > asset.dueDate, "Due date not passed");

        _claimReward(collection, assetId);
        _stableToken.safeTransferFrom(
            _treasuryWallet,
            asset.owner,
            asset.price
        );
        _transferAsset(collection, address(this), asset.owner, assetId);
        delete _assets[address(_assetCollection)][assetId];

        emit AssetSettled(collection, asset.owner, assetId);
    }

    /**
     * @dev See {IMarketplace-relist}.
     */
    function relist(
        address collection,
        uint256 assetId,
        uint256 salePrice
    ) external {
        AssetInfo storage asset = _assets[collection][assetId];
        require(asset.owner == _msgSender(), "You are not the owner");
        asset.salePrice = salePrice;

        emit AssetRelisted(collection, assetId, salePrice);
    }

    /**
     * @dev See {IMarketplace-counterOffer}.
     */
    function counterOffer(
        address owner,
        address offeror,
        uint256 offerPrice,
        uint256 assetId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Offer expired");
        require(
            owner == _assets[address(_assetCollection)][assetId].owner,
            "Signer is not the owner"
        );
        require(offeror == _msgSender(), "You are not the offeror");

        bytes32 offerHash = keccak256(
            abi.encode(
                _OFFER_TYPEHASH,
                owner,
                offeror,
                offerPrice,
                assetId,
                _useNonce(owner),
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(offerHash);
        address signer = ECDSA.recover(hash, v, r, s);

        require(signer == owner, "Invalid signature");
        _buy(address(_assetCollection), assetId, offerPrice);
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(address collection, uint256 assetId) external {
        _buy(collection, assetId, _assets[collection][assetId].salePrice);
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(
        address[] calldata collections,
        uint256[] calldata assetIds
    ) external {
        require(collections.length == assetIds.length, "No array parity");
        for (uint256 i = 0; i < assetIds.length; ) {
            _buy(
                collections[i],
                assetIds[i],
                _assets[collections[i]][assetIds[i]].salePrice
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function claimReward(address collection, uint256 assetId) external {
        AssetInfo memory asset = _assets[collection][assetId];
        require(asset.owner == _msgSender(), "You are not the owner");
        _claimReward(collection, assetId);
    }

    /**
     * @dev See {IMarketplace-setInitialFee}.
     */
    function setInitialFee(
        uint256 initialFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = _initialFee;
        _initialFee = initialFee_;

        emit InitialFeeSet(oldFee, _initialFee);
    }

    /**
     * @dev See {IMarketplace-setBuyingFee}.
     */
    function setBuyingFee(
        uint256 buyingFee_
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 oldFee = _buyingFee;
        _buyingFee = buyingFee_;

        emit BuyingFeeSet(oldFee, _buyingFee);
    }

    /**
     * @dev See {IMarketplace-setTreasuryWallet}.
     */
    function setTreasuryWallet(
        address newTreasuryWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setTreasuryWallet(newTreasuryWallet);
    }

    /**
     * @dev See {IMarketplace-setFeeWallet}.
     */
    function setFeeWallet(
        address newFeeWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
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
     * @dev See {IMarketplace-getTreasuryWallet}.
     */
    function getTreasuryWallet() external view returns (address) {
        return address(_treasuryWallet);
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
     * @dev "Consume a nonce": return the current value and increment
     */
    function _useNonce(
        address owner
    ) internal virtual returns (uint256 current) {
        current = _currentNonce[owner];
        _currentNonce[owner]++;
    }

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @dev Wallet can be EOA or multisig
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function _setTreasuryWallet(address newTreasuryWallet) private {
        require(newTreasuryWallet != address(0), "Invalid wallet address");

        address oldTreasuryWallet = address(_treasuryWallet);
        _treasuryWallet = newTreasuryWallet;

        emit TreasuryWalletSet(oldTreasuryWallet, newTreasuryWallet);
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
     * @dev Transfers asset to buyer and transfer the price to treasury wallet
     * @param assetId, unique identifier of the asset
     */
    function _claimReward(uint256 assetId) private {
        address owner = _assetCollection.getAssetInfo(assetId).owner;
        uint256 reward = _assetCollection.updateClaim(assetId);

        _stableToken.safeTransferFrom(_treasuryWallet, owner, reward);

        emit RewardsClaimed(owner, reward);
    }

    /**
     * @dev Safe transfer asset to buyer and transfer the price to treasury wallet
     * @dev Transfer buying fee or initial fee to fee wallet based on asset status
     * @param assetId, unique identifier of the asset
     */
    function _buy(uint256 assetId, uint256 salePrice) private {
        require(
            _assetCollection.getAssetInfo(assetId).salePrice != 0,
            "Asset is not listed"
        );
        uint256 lastClaimDate = _assetCollection
            .getAssetInfo(assetId)
            .lastClaimDate;
        address owner = _assetCollection.getAssetInfo(assetId).owner;
        uint256 fee = lastClaimDate != 0 ? _buyingFee : _initialFee;
        address receiver = lastClaimDate != 0 ? owner : _treasuryWallet;

        fee = (salePrice * fee) / 1e4;

        if (lastClaimDate == 0) _assetCollection.updateClaim(assetId);

        _assetCollection.safeTransferFrom(
            owner,
            _msgSender(),
            assetId,
            1,
            1,
            ""
        );

        _stableToken.safeTransferFrom(_msgSender(), receiver, salePrice);
        _stableToken.safeTransferFrom(_msgSender(), _feeWallet, fee);

        emit AssetBought(owner, _msgSender(), assetId);
    }
}
