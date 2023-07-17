// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "dual-layer-token/contracts/DLT/interfaces/IDLTReceiver.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "contracts/Token/interface/IToken.sol";
import "contracts/Asset/interface/IAsset.sol";

/**
 * @title The common marketplace for the assets
 * @author Polytrade.Finance
 * @dev Implementation of all assets trading operations
 */
contract Marketplace is
    Context,
    ERC165,
    EIP712,
    AccessControl,
    IMarketplace,
    IDLTReceiver
{
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    uint256 private constant _YEAR = 360 days;

    uint256 private _initialFee;
    uint256 private _buyingFee;

    IAsset private immutable _assetCollection;
    IToken private immutable _stableToken;

    address private _treasuryWallet;
    address private _feeWallet;

    /**
     * @dev Mapping will be indexing the AssetInfo for asset collection by its id
     */
    mapping(uint256 => PropertyInfo) private _properties;
    mapping(uint256 => mapping(uint256 => AssetInfo)) private _assets;
    mapping(address => uint256) private _currentNonce;

    // solhint-disable-next-line var-name-mixedcase
    bytes32 private constant _OFFER_TYPEHASH =
        keccak256(
            abi.encodePacked(
                "CounterOffer(",
                "address owner,",
                "address offeror,",
                "uint256 offerPrice,",
                "uint256 assetType,",
                "uint256 assetId,",
                "uint256 nonce,",
                "uint256 deadline",
                ")"
            )
        );
    bytes4 private constant _ASSET_INTERFACE_ID = type(IAsset).interfaceId;

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
     * @dev See {IMarketplace-createProperty}.
     */
    function createProperty(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 dueDate,
        PropertyInfo calldata propertyInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _properties[assetId] = propertyInfo;
        _createAsset(owner, 2, assetId, price, 0, dueDate);
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
        _createAsset(owner, 1, assetId, price, apr, dueDate);
    }

    /**
     * @dev See {IMarketplace-createAsset}.
     */
    function burnAsset(
        address owner,
        uint256 assetType,
        uint256 assetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetCollection.burnAsset(owner, assetType, assetId);
        delete _assets[assetType][assetId];
    }

    /**
     * @dev See {IMarketplace-batchCreateAsset}.
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata assetIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = assetIds.length;
        require(
            owners.length == length &&
                length == prices.length &&
                length == dueDates.length &&
                length == aprs.length,
            "No array parity"
        );

        for (uint256 i = 0; i < length; ) {
            _createAsset(
                owners[i],
                1,
                assetIds[i],
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
     * @dev See {IMarketplace-settleProperty}.
     */
    function settleProperty(
        uint256 assetId,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AssetInfo memory asset = _assets[2][assetId];
        require(amount != 0, "Invalid settle amount");
        require(asset.owner != address(0), "Invalid asset id");
        require(block.timestamp > asset.dueDate, "Due date not passed");

        _stableToken.safeTransferFrom(_treasuryWallet, asset.owner, amount);
        _assetCollection.safeTransferFrom(
            address(this),
            asset.owner,
            2,
            assetId,
            1,
            ""
        );
        delete _assets[2][assetId];

        emit AssetSettled(asset.owner, 2, assetId);
    }

    /**
     * @dev See {IMarketplace-settleAsset}.
     */
    function settleAsset(
        uint256 assetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        AssetInfo memory asset = _assets[1][assetId];
        require(asset.owner != address(0), "Invalid asset id");
        require(block.timestamp > asset.dueDate, "Due date not passed");

        _claimReward(1, assetId);
        _stableToken.safeTransferFrom(
            _treasuryWallet,
            asset.owner,
            asset.price
        );
        _assetCollection.safeTransferFrom(
            address(this),
            asset.owner,
            1,
            assetId,
            1,
            ""
        );
        delete _assets[1][assetId];

        emit AssetSettled(asset.owner, 1, assetId);
    }

    /**
     * @dev See {IMarketplace-relist}.
     */
    function relist(
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice
    ) external {
        AssetInfo storage asset = _assets[assetType][assetId];
        require(asset.owner == _msgSender(), "You are not the owner");
        asset.salePrice = salePrice;

        emit AssetRelisted(asset.owner, assetType, assetId, salePrice);
    }

    /**
     * @dev See {IMarketplace-counterOffer}.
     */
    function counterOffer(
        address owner,
        address offeror,
        uint256 offerPrice,
        uint256 assetType,
        uint256 assetId,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "Offer expired");
        require(
            owner == _assets[assetType][assetId].owner,
            "Signer is not the owner"
        );
        require(offeror == _msgSender(), "You are not the offeror");
        uint256 nonce = _useNonce(owner);
        bytes32 offerHash = keccak256(
            abi.encode(
                _OFFER_TYPEHASH,
                owner,
                offeror,
                offerPrice,
                assetType,
                assetId,
                nonce,
                deadline
            )
        );

        bytes32 hash = _hashTypedDataV4(offerHash);
        address signer = ECDSA.recover(hash, v, r, s);

        require(signer == owner, "Invalid signature");
        _buy(assetType, assetId, offerPrice);
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(uint256 assetType, uint256 assetId) external {
        _buy(assetType, assetId, _assets[assetType][assetId].salePrice);
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(
        uint256[] calldata assetTypes,
        uint256[] calldata assetIds
    ) external {
        uint256 length = assetIds.length;
        require(assetTypes.length == length, "No array parity");
        for (uint256 i = 0; i < length; ) {
            _buy(
                assetTypes[i],
                assetIds[i],
                _assets[assetTypes[i]][assetIds[i]].salePrice
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-claimReward}.
     */
    function claimReward(uint256 assetType, uint256 assetId) external {
        AssetInfo memory asset = _assets[assetType][assetId];
        require(asset.owner == _msgSender(), "You are not the owner");
        _claimReward(assetType, assetId);
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
     * @dev See {IMarketplace-getAssetInfo}.
     */
    function getAssetInfo(
        uint256 assetType,
        uint256 assetId
    ) external view returns (AssetInfo memory) {
        return _assets[assetType][assetId];
    }

    /**
     * @dev See {IMarketplace-getPropertyInfo}.
     */
    function getPropertyInfo(
        uint256 assetId
    ) external view returns (PropertyInfo memory) {
        return _properties[assetId];
    }

    /**
     * @dev See {IMarketplace-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 assetType,
        uint256 assetId
    ) external view returns (uint256 reward) {
        AssetInfo memory asset = _assets[assetType][assetId];
        uint256 tenure;

        if (asset.lastClaimDate != 0) {
            tenure = asset.dueDate - asset.lastClaimDate;
        } else if (asset.price != 0) {
            tenure =
                asset.dueDate -
                (
                    block.timestamp > asset.dueDate
                        ? asset.dueDate
                        : block.timestamp
                );
        }
        reward = _calculateFormula(asset.price, tenure, asset.rewardApr);
    }

    /**
     * @dev See {IMarketplace-getAvailableReward}.
     */
    function getAvailableReward(
        uint256 assetType,
        uint256 assetId
    ) external view returns (uint256) {
        return _getAvailableReward(assetType, assetId);
    }

    function onDLTReceived(
        address,
        address,
        uint256,
        uint256,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onDLTReceived.selector;
    }

    function onDLTBatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        uint256[] memory,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onDLTBatchReceived.selector;
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
     * @dev Called in createAsset and batchCreateAsset functions
     * @dev Calls _listAsset to store parameters
     * @param owner, initial owner of asset
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param apr, annual percentage rate for calculating rewards
     * @param dueDate, end date for calculating rewards
     */
    function _createAsset(
        address owner,
        uint256 assetType,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) private {
        require(
            _assetCollection.totalSubSupply(assetType, assetId) == 0,
            "Asset already created"
        );
        _assetCollection.createAsset(owner, assetType, assetId);
        _listAsset(owner, assetType, assetId, price, apr, dueDate);
    }

    /**
     * @dev Called when asset creates
     * @param owner, address of asset owner
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell and settle
     * @param apr, annual percentage rate for calculating rewards
     * @param dueDate, end date for calculating rewards
     */
    function _listAsset(
        address owner,
        uint256 assetType,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) private {
        _assets[assetType][assetId] = AssetInfo(
            owner,
            price,
            price,
            apr,
            dueDate,
            0
        );
        emit AssetListed(owner, assetType, assetId, price);
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
     * @dev Transfers rewards to owner and updates lastClaimDate
     * @param assetId, unique identifier of the asset
     */
    function _claimReward(uint256 assetType, uint256 assetId) private {
        AssetInfo memory asset = _assets[assetType][assetId];

        uint256 reward = _getAvailableReward(assetType, assetId);
        _assets[assetType][assetId].lastClaimDate = (
            block.timestamp > asset.dueDate ? asset.dueDate : block.timestamp
        );

        _stableToken.safeTransferFrom(_treasuryWallet, asset.owner, reward);

        emit RewardsClaimed(asset.owner, assetType, assetId, reward);
    }

    /**
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Transfer buying fee or initial fee to fee wallet based on asset status
     * @param assetId, unique identifier of the asset
     * @param salePrice, unique identifier of the asset
     */
    function _buy(
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice
    ) private {
        AssetInfo memory asset = _assets[assetType][assetId];
        require(asset.salePrice != 0, "Asset is not relisted");
        require(asset.dueDate > block.timestamp, "Due date has passed");
        uint256 fee = asset.lastClaimDate != 0 ? _buyingFee : _initialFee;
        address receiver = asset.lastClaimDate != 0
            ? asset.owner
            : _treasuryWallet;
        fee = (salePrice * fee) / 1e4;

        if (asset.lastClaimDate == 0) {
            _assets[assetType][assetId].lastClaimDate = block.timestamp;
            _assetCollection.safeTransferFrom(
                asset.owner,
                address(this),
                assetType,
                assetId,
                1,
                ""
            );
        }
        _assets[assetType][assetId].owner = _msgSender();
        _assets[assetType][assetId].salePrice = 0;

        _stableToken.safeTransferFrom(_msgSender(), receiver, salePrice);
        _stableToken.safeTransferFrom(_msgSender(), _feeWallet, fee);
        emit AssetBought(
            asset.owner,
            _msgSender(),
            assetType,
            assetId,
            salePrice
        );
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param assetId, unique identifier of asset
     * @return reward , accumulated rewards for the current owner
     */
    function _getAvailableReward(
        uint256 assetType,
        uint256 assetId
    ) private view returns (uint256 reward) {
        AssetInfo memory asset = _assets[assetType][assetId];

        if (asset.lastClaimDate != 0) {
            uint256 tenure = (
                block.timestamp > asset.dueDate
                    ? asset.dueDate
                    : block.timestamp
            ) - asset.lastClaimDate;

            reward = _calculateFormula(asset.price, tenure, asset.rewardApr);
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
