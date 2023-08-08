// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "contracts/Token/interface/IToken.sol";
import "contracts/Asset/interface/IAsset.sol";

/**
 * @title The common marketplace for the assets
 * @author Zakrad
 * @dev Implementation of all assets trading operations
 */
contract Marketplace is
    Initializable,
    Context,
    ERC165,
    EIP712Upgradeable,
    AccessControl,
    IMarketplace
{
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    uint256 private constant _YEAR = 360 days;

    uint256 private _initialFee;
    uint256 private _buyingFee;

    IAsset private _assetCollection;
    IToken private _stableToken;

    address private _treasuryWallet;
    address private _feeWallet;

    /**
     * @dev Mapping will be indexing the AssetInfo for asset collection by its id
     */
    mapping(uint256 => PropertyInfo) private _properties;
    mapping(uint256 => mapping(uint256 => AssetInfo)) private _assets;
    mapping(uint256 => mapping(uint256 => mapping(address => ListedInfo)))
        private _listedInfo;
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
                "uint256 fractionsToBuy,",
                "uint256 nonce,",
                "uint256 deadline",
                ")"
            )
        );
    bytes4 private constant _ASSET_INTERFACE_ID = type(IAsset).interfaceId;

    /**
     * @dev Initializer for the main Marketplace
     * @param assetCollection_, Address of the asset collection used in the marketplace
     * @param tokenAddress_, Address of the ERC20 token address
     * @param treasuryWallet_, Address of the treasury wallet
     * @param feeWallet_, Address of the fee wallet
     */
    function initialize(
        address assetCollection_,
        address tokenAddress_,
        address treasuryWallet_,
        address feeWallet_
    ) external initializer {
        __EIP712_init("Polytrade", "2.2");
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
        uint256 minFraction,
        PropertyInfo calldata propertyInfo
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _properties[assetId] = propertyInfo;
        _createAsset(owner, 2, assetId, price, 0, dueDate, minFraction);
    }

    /**
     * @dev See {IMarketplace-createAsset}.
     */
    function createAsset(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate,
        uint256 minFraction
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createAsset(owner, 1, assetId, price, apr, dueDate, minFraction);
    }

    /**
     * @dev See {IMarketplace-batchCreateAsset}.
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata assetIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates,
        uint256[] calldata minFractions
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = assetIds.length;
        require(
            owners.length == length &&
                length == prices.length &&
                length == dueDates.length &&
                length == aprs.length &&
                length == minFractions.length,
            "No array parity"
        );

        for (uint256 i = 0; i < length; ) {
            _createAsset(
                owners[i],
                1,
                assetIds[i],
                prices[i],
                aprs[i],
                dueDates[i],
                minFractions[i]
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
        address owner,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(amount != 0, "Invalid settle amount");
        _settleAsset(2, assetId, owner, amount);
    }

    /**
     * @dev See {IMarketplace-settleAsset}.
     */
    function settleAsset(
        uint256 assetId,
        address owner
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _claimReward(1, assetId, owner);
        _settleAsset(1, assetId, owner, _assets[1][assetId].price);
    }

    /**
     * @dev See {IMarketplace-batchSettleAsset}.
     */
    function batchSettleAsset(
        uint256[] calldata assetIds,
        address[] calldata owners
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = assetIds.length;
        require(owners.length == length, "No array parity");
        for (uint256 i = 0; i < length; ) {
            _claimReward(1, assetIds[i], owners[i]);
            _settleAsset(
                1,
                assetIds[i],
                owners[i],
                _assets[1][assetIds[i]].price
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IMarketplace-relist}.
     */
    function relist(
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice,
        uint256 minFraction
    ) external {
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            _msgSender(),
            assetType,
            assetId
        );
        require(minFraction != 0, "Min. fraction can not be zero");
        require(subBalanceOf != 0, "Not enough balance");
        require(subBalanceOf >= minFraction, "Min. fraction > Balance");

        _listedInfo[assetType][assetId][_msgSender()] = ListedInfo(
            salePrice,
            minFraction
        );

        emit AssetRelisted(
            _msgSender(),
            assetType,
            assetId,
            salePrice,
            minFraction
        );
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
        uint256 fractionsToBuy,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        {
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
            _buy(assetType, assetId, offerPrice, fractionsToBuy, owner);
        }
    }

    /**
     * @dev See {IMarketplace-buy}.
     */
    function buy(
        uint256 assetType,
        uint256 assetId,
        uint256 fractionToBuy,
        address owner
    ) external {
        _buy(
            assetType,
            assetId,
            _listedInfo[assetType][assetId][owner].salePrice,
            fractionToBuy,
            owner
        );
    }

    /**
     * @dev See {IMarketplace-batchBuy}.
     */
    function batchBuy(
        uint256[] calldata assetTypes,
        uint256[] calldata assetIds,
        uint256[] calldata fractionsToBuy,
        address[] calldata owners
    ) external {
        uint256 length = assetIds.length;
        require(
            assetTypes.length == length &&
                length == fractionsToBuy.length &&
                length == owners.length,
            "No array parity"
        );
        for (uint256 i = 0; i < length; ) {
            _buy(
                assetTypes[i],
                assetIds[i],
                _listedInfo[assetTypes[i]][assetIds[i]][owners[i]].salePrice,
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

        if (asset.purchaseDate != 0) {
            tenure = asset.dueDate - asset.purchaseDate;
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
     * @param assetType, type of asset to create
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param apr, annual percentage rate for calculating rewards
     * @param dueDate, end date for calculating rewards
     * @param minFraction, Minimum fraction needs for buying the asset
     */
    function _createAsset(
        address owner,
        uint256 assetType,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate,
        uint256 minFraction
    ) private {
        require(
            _assetCollection.totalSubSupply(assetType, assetId) == 0,
            "Asset already created"
        );

        _assetCollection.createAsset(owner, assetType, assetId);
        _assets[assetType][assetId] = AssetInfo(owner, price, apr, dueDate, 0);
        _listedInfo[assetType][assetId][owner] = ListedInfo(price, minFraction);

        emit AssetListed(owner, assetType, assetId, price);
    }

    /**
     * @dev Called in settleAsset and batchSettleAsset functions
     * @param assetId, unique identifier of asset
     * @param owner, address of the owner for settlement
     */
    function _settleAsset(
        uint256 assetType,
        uint256 assetId,
        address owner,
        uint256 settlePrice
    ) private {
        AssetInfo memory asset = _assets[assetType][assetId];
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            assetType,
            assetId
        );

        require(asset.dueDate != 0, "Invalid asset id");
        require(subBalanceOf != 0, "Not enough balance");
        require(block.timestamp > asset.dueDate, "Due date not passed");

        settlePrice = (settlePrice * subBalanceOf) / 1e4;
        _stableToken.safeTransferFrom(_treasuryWallet, owner, settlePrice);
        _assetCollection.burnAsset(owner, assetType, assetId, subBalanceOf);

        delete _listedInfo[assetType][assetId][owner];
        if (_assetCollection.totalSubSupply(assetType, assetId) == 0) {
            delete _assets[assetType][assetId];
        }

        emit AssetSettled(asset.owner, assetType, assetId);
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
     * @dev Transfers rewards to owner and updates purchaseDate
     * @param assetType, type of asset to claim reward
     * @param assetId, unique identifier of the asset
     * @param receiver, address of receiver reward
     */
    function _claimReward(
        uint256 assetType,
        uint256 assetId,
        address receiver
    ) private {
        AssetInfo memory asset = _assets[assetType][assetId];

        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            receiver,
            assetType,
            assetId
        );
        uint256 reward = (_getAvailableReward(assetType, assetId) *
            subBalanceOf) / 1e4;
        _assets[assetType][assetId].purchaseDate = (
            block.timestamp > asset.dueDate ? asset.dueDate : block.timestamp
        );

        _stableToken.safeTransferFrom(_treasuryWallet, receiver, reward);

        emit RewardsClaimed(receiver, assetType, assetId, reward);
    }

    /**
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Transfer buying fee or initial fee to fee wallet based on asset status
     * @param assetType, type of asset to buy
     * @param assetId, unique identifier of the asset
     * @param salePrice, sale price for buying specific fraction of asset
     * @param fractionToBuy, number of fractions to buy from owner address
     * @param owner, address of owner of the fraction of asset
     */
    function _buy(
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice,
        uint256 fractionToBuy,
        address owner
    ) private {
        AssetInfo memory asset = _assets[assetType][assetId];
        uint256 ownerBalance = _assetCollection.subBalanceOf(
            owner,
            assetType,
            assetId
        );

        require(
            fractionToBuy >= _listedInfo[assetType][assetId][owner].minFraction,
            "Fraction to buy < Min. fraction"
        );
        require(fractionToBuy <= ownerBalance, "Not enough fraction to buy");
        require(salePrice != 0, "Asset is not relisted");
        require(asset.dueDate > block.timestamp, "Due date has passed");

        uint256 payPrice = (salePrice * fractionToBuy) / 1e4;
        uint256 fee = asset.owner != owner ? _buyingFee : _initialFee;
        address receiver = asset.owner != owner ? asset.owner : _treasuryWallet;
        fee = (payPrice * fee) / 1e4;
        if (asset.purchaseDate == 0) {
            _assets[assetType][assetId].purchaseDate = block.timestamp;
        }
        if (ownerBalance == fractionToBuy) {
            delete _listedInfo[assetType][assetId][owner];
        }

        _assetCollection.safeTransferFrom(
            owner,
            _msgSender(),
            assetType,
            assetId,
            fractionToBuy,
            ""
        );
        _stableToken.safeTransferFrom(_msgSender(), receiver, payPrice);
        _stableToken.safeTransferFrom(_msgSender(), _feeWallet, fee);
        emit AssetBought(
            owner,
            _msgSender(),
            assetType,
            assetId,
            salePrice,
            payPrice
        );
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param assetType, type of asset to get available rewards
     * @param assetId, unique identifier of asset
     */
    function _getAvailableReward(
        uint256 assetType,
        uint256 assetId
    ) private view returns (uint256 reward) {
        AssetInfo memory asset = _assets[assetType][assetId];

        if (asset.purchaseDate != 0) {
            uint256 tenure = (
                block.timestamp > asset.dueDate
                    ? asset.dueDate
                    : block.timestamp
            ) - asset.purchaseDate;

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
