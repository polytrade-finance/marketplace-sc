// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title The main interface to define the main marketplace
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the marketplace
 */
interface IMarketplace {
    /**
     * @title A struct that defines the asset information
     * @param owner, is the address of owner of asset
     * @param price, is the price of asset
     * @param rewardApr, is the Apr for calculating rewards
     * @param dueDate, is the end date for caluclating rewards
     * @param purchaseDate, is the date of the first purchase
     */
    struct AssetInfo {
        address owner;
        uint256 price;
        uint256 rewardApr;
        uint256 dueDate;
        uint256 purchaseDate;
    }

    /**
     * @title Listed information for each asset owner and asset id
     * @param salePrice, is the sale price of asset
     * @param minFraction, minimum fraction required for buying an asset
     */
    struct ListedInfo {
        uint256 salePrice;
        uint256 minFraction;
    }

    /**
     * @title storing property information
     * @param value, is the value of the property
     * @param size, is the size of the property is sq2
     * @param rooms, is the number of the rooms
     * @param bathrooms, is the number of the bathrooms
     * @param constructionDate, is the date of property construction
     * @param country, is the location country
     * @param city, is the location city
     * @param location, is the google map location
     */
    struct PropertyInfo {
        uint256 value;
        uint256 size;
        uint256 rooms;
        uint256 bathrooms;
        uint256 constructionDate;
        string country;
        string city;
        string location;
    }

    /**
     * @dev Emitted when an asset is listed with it's parameters for an owner
     * @param owner, Address of the initial onvoice owner
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, assetId is the unique identifier of asset
     * @param price, assetId is the unique identifier of asset
     */
    event AssetListed(
        address indexed owner,
        uint256 assetType,
        uint256 assetId,
        uint256 price
    );

    /**
     * @dev Emitted when new `Treasury Wallet` has been set
     * @param oldTreasuryWallet, Address of the old treasury wallet
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    event TreasuryWalletSet(
        address oldTreasuryWallet,
        address newTreasuryWallet
    );

    /**
     * @dev Emitted when new `Fee Wallet` has been set
     * @param oldFeeWallet, Address of the old fee wallet
     * @param newFeeWallet, Address of the new fee wallet
     */
    event FeeWalletSet(address oldFeeWallet, address newFeeWallet);

    /**
     * @dev Emitted when new rewards claimed by current owner
     * @param receiver, Address of reward receiver
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, assetId is the unique identifier of asset
     * @param reward, Amount of rewards received
     */
    event RewardsClaimed(
        address indexed receiver,
        uint256 assetType,
        uint256 assetId,
        uint256 reward
    );

    /**
     * @dev Emitted when asset owner changes
     * @param oldOwner, Address of the previous owner
     * @param newOwner, Address of the new owner
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, id of the bought asset
     *  @ @param payPrice, the price buyer pays that is fraction of salePrice
     */
    event AssetBought(
        address indexed oldOwner,
        address indexed newOwner,
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice,
        uint256 payPrice
    );

    /**
     * @dev Emitted when a new initial fee set
     * @dev initial fee applies to the first buy
     * @param oldFee, old initial fee percentage
     * @param newFee, old initial fee percentage
     */
    event InitialFeeSet(uint256 oldFee, uint256 newFee);

    /**
     * @dev Emitted when a new buying fee set
     * @dev buying fee applies to the all buyings instead of first one
     * @param oldFee, old buying fee percentage
     * @param newFee, old buying fee percentage
     */
    event BuyingFeeSet(uint256 oldFee, uint256 newFee);

    /**
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique number of the asset
     * @param settlePrice, paid amount for settlement
     */
    event AssetSettled(
        address indexed owner,
        uint256 assetType,
        uint256 assetId,
        uint256 settlePrice
    );

    /**
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique number of the asset
     * @param salePrice, unique number of the asset
     * @param minFraction, minimum fraction needed to buy
     */
    event AssetRelisted(
        address indexed owner,
        uint256 indexed assetType,
        uint256 indexed assetId,
        uint256 salePrice,
        uint256 minFraction
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev add bank token address to a specific id
     * @dev used for identifying bank of buyers
     * @param id, id of bank, id 0 is default for settlment and treasury wallet interactions
     * @param bankAddress, id of bank token address
     */
    function addBankAccount(uint256 id, address bankAddress) external;

    /**
     * @dev Creates an asset with its parameters
     * @param owner, initial owner of asset
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param dueDate, end date for calculating rewards
     * @param apr, annual percentage rate for calculating rewards
     * @param minFraction, minimum amount of fraction needs to buy from this asset
     * @dev Needs admin access to create an asset
     */
    function createAsset(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate,
        uint256 minFraction
    ) external;

    /**
     * @dev Creates a property with its parameters
     * @param owner, initial owner of property
     * @param assetId, unique identifier of property
     * @param price, property price to sell
     * @param dueDate, minimum locking duration for property
     * @param minFraction, minimum fraction of asset owner set for buyers
     * @param propertyInfo, is the property information in PropertyInfo format
     * @dev Needs admin access to create an asset
     */
    function createProperty(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 dueDate,
        uint256 minFraction,
        PropertyInfo calldata propertyInfo
    ) external;

    /**
     * @dev Creates batch asset with their parameters
     * @param owners, initial owners of assets
     * @param assetIds, unique identifiers of assets
     * @param prices, assets price to sell
     * @param dueDates, end dates for calculating rewards
     * @param aprs, annual percentage rates for calculating rewards
     * @param minFractions, array of minimum fractions needed for buying from an asset
     * @dev Needs admin access to batch create asset
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata assetIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates,
        uint256[] calldata minFractions
    ) external;

    /**
     * @dev Settles an asset after due date and claim remaining rewards for the owner
     * @dev Transfer back the asset and transfers the price to current owner
     * @dev Transfer price to current owner
     * @dev Deletes the stored parameters
     * @param assetId, unique number of the asset
     * @param owner, address of the owner of asset
     */
    function settleAsset(uint256 assetId, address owner) external;

    /**
     * @dev settle batch asset with their parameters
     * @param assetIds, unique identifiers of assets
     * @param owners, initial owners of assets
     * @dev Needs admin access to batch settle asset
     */
    function batchSettleAsset(
        uint256[] calldata assetIds,
        address[] calldata owners
    ) external;

    /**
     * @dev Settles an asset after due date and sends the amount to owner
     * @dev burn the asset
     * @dev Transfer amount to current owner
     * @dev Deletes the stored parameters
     * @param assetId, unique number of the asset
     * @param owner, address of the owner of asset
     * @param amount, amount of token transfers to owner
     */
    function settleProperty(
        uint256 assetId,
        address owner,
        uint256 amount
    ) external;

    /**
     * @dev Settles the remaining unsold fractions of an asset
     * @dev Deletes the stored parameters
     * @param assetType, unique identifier of the asset type
     * @param assetId, unique identifier of the asset
     */
    function settleUnsold(uint256 assetType, uint256 assetId) external;

    /**
     * @dev Changes owner to buyer
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @param bankId, Id of the bank which buyer is using its wallet
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique number of the asset
     * @param fractionToBuy, amount of fraction for buying
     * @param owner, address of the owner of asset
     */
    function buy(
        uint256 bankId,
        uint256 assetType,
        uint256 assetId,
        uint256 fractionToBuy,
        address owner
    ) external;

    /**
     * @dev Batch buy assets from owners
     * @dev Loop through arrays and calls the buy function
     * @param assetTypes, arrray of assetTypes that identifies whether its a property or an invoice
     * @param bankId, Id of the bank which buyer is using its wallet
     * @param assetIds, unique identifiers of the assets
     * @param fractionsToBuy, amounts of fraction for buying
     * @param owners, addresses of the owner of asset
     */
    function batchBuy(
        uint256 bankId,
        uint256[] calldata assetTypes,
        uint256[] calldata assetIds,
        uint256[] calldata fractionsToBuy,
        address[] calldata owners
    ) external;

    /**
     * @dev Relist an asset for the current owner
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique identifier of the asset
     * @param salePrice, new price for asset sale
     * @param minFraction, minFraction owner set for buyers
     */
    function relist(
        uint256 assetType,
        uint256 assetId,
        uint256 salePrice,
        uint256 minFraction
    ) external;

    /**
     * @dev Set new initial fee
     * @dev Initial fee applies to the first buy
     * @dev Needs admin access to set
     * @param initialFee_, new initial fee percentage with 2 decimals
     */
    function setInitialFee(uint256 initialFee_) external;

    /**
     * @dev Set new buying fee
     * @dev Buying fee applies to the all buyings instead of first one
     * @dev Needs admin access to set
     * @param buyingFee_, new buying fee percentage with 2 decimals
     */
    function setBuyingFee(uint256 buyingFee_) external;

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function setTreasuryWallet(address newTreasuryWallet) external;

    /**
     * @dev Allows to set a new fee wallet address where buying fees will be allocated.
     * @param newFeeWallet, Address of the new fee wallet
     */
    function setFeeWallet(address newFeeWallet) external;

    /**
     * @dev Allows to buy asset with a signed message by owner with agreed sale price
     * @param owner, Address of the owner of asset
     * @param offeror, Address of the offeror
     * @param offerPrice, offered price for buying asset
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, asset id to buy
     * @param fractionsToBuy, amount of fractions o buy from owner
     * @param deadline, The expiration date of this agreement
     * Requirements:
     *
     * - `offeror` must be the msg.sender.
     * - `owner` should own the asset id.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce
     */
    function counterOffer(
        address owner,
        address offeror,
        uint256 offerPrice,
        uint256 bankId,
        uint256 assetType,
        uint256 assetId,
        uint256 fractionsToBuy,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Gets current asset collection address
     * @return address, Address of the invocie collection contract
     */
    function getAssetCollection() external view returns (address);

    /**
     * @dev Gets current stable token address
     * @param id of bank to receive added bank token address
     * @return address, Address of the stable token contract
     */
    function getStableToken(uint256 id) external view returns (address);

    /**
     * @dev Gets current treasury wallet address
     * @return address, Address of the treasury wallet
     */
    function getTreasuryWallet() external view returns (address);

    /**
     * @dev Gets current fee wallet address
     * @return address Address of the fee wallet
     */
    function getFeeWallet() external view returns (address);

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {counterOffer}.
     *
     * Every successful call to {counterOffer} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Gets the domain separator used in the encoding of the signature for {counterOffer}, as defined by {EIP712}.
     * @return bytes32 of the domain separator
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @dev Gets initial fee percentage that applies to first buyings
     * @return percentage of initial fee with 2 decimals
     */
    function getInitialFee() external view returns (uint256);

    /**
     * @dev Gets buying fee percentage that applies to all buyings except first one
     * @return percentage of buying fee with 2 decimals
     */
    function getBuyingFee() external view returns (uint256);

    /**
     * @dev Calculates the remaning reward
     * @param assetId, unique identifier of asset
     * @param assetType, assetType identifies whether its a property or an invoice
     * @return reward the rewards Amount
     */
    function getRemainingReward(
        uint256 assetType,
        uint256 assetId
    ) external view returns (uint256 reward);

    /**
     * @dev Calculates available rewards to claim
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique identifier of asset
     * @return reward the accumulated rewards amount for the current owner
     */
    function getAvailableReward(
        uint256 assetType,
        uint256 assetId
    ) external view returns (uint256 reward);

    /**
     * @dev Gets the asset information
     * @param assetType, assetType identifies whether its a property or an invoice
     * @param assetId, unique identifier of asset
     * @return AssetInfo struct
     */
    function getAssetInfo(
        uint256 assetType,
        uint256 assetId
    ) external view returns (AssetInfo memory);

    /**
     * @dev Gets the property information
     * @param assetId, unique identifier of asset
     * @return PropertyInfo struct
     */
    function getPropertyInfo(
        uint256 assetId
    ) external view returns (PropertyInfo memory);
}
