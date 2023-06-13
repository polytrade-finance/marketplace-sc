// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

/**
 * @title The main interface to define the main marketplace
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the marketplace
 */
interface IMarketplace {
    /**
     * @title A new struct to define the asset information
     * @param owner, is the address of owner of asset
     * @param price, is the price of asset
     * @param salePrice, is the sale price of asset
     * @param rewardApr, is the Apr for calculating rewards
     * @param dueDate, is the end date for caluclating rewards
     * @param lastClaimDate, is the date of last claim rewards
     */
    struct AssetInfo {
        address owner;
        uint256 price;
        uint256 salePrice;
        uint256 rewardApr;
        uint256 dueDate;
        uint256 lastClaimDate;
    }

    /**
     * @dev Emitted when an asset is listed with it's parameters for an owner
     * @param collection, Address of the asset collection
     * @param owner, Address of the initial onvoice owner
     * @param assetId, assetId is the unique identifier of asset
     */
    event AssetListed(
        address indexed collection,
        address indexed owner,
        uint256 assetId
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
     * @param reward, Amount of rewards received
     */
    event RewardsClaimed(address indexed receiver, uint256 reward);

    /**
     * @dev Emitted when asset owner changes
     * @param collection, Address of the asset collection
     * @param oldOwner, Address of the previous owner
     * @param newOwner, Address of the new owner
     * @param assetId, idof the bought asset
     */
    event AssetBought(
        address indexed collection,
        address indexed oldOwner,
        address indexed newOwner,
        uint256 assetId
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
     * @param collection, Address of the asset collection
     * @param owner, address of the asset owner
     * @param assetId, unique number of the asset
     */
    event AssetSettled(
        address indexed collection,
        address indexed owner,
        uint256 assetId
    );

    /**
     * @dev Emitted when an asset is settled
     * @param collection, Address of the asset collection
     * @param assetId, unique number of the asset
     * @param salePrice, unique number of the asset
     */
    event AssetRelisted(
        address indexed collection,
        uint256 assetId,
        uint256 salePrice
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Creates an asset with erc721 implementation
     * @param collection, Address of the asset collection
     * @param owner, initial owner of asset
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param apr, annual percentage rate for calculating rewards
     * @param dueDate, end date for calculating rewards
     * @dev Needs admin access to create an asset
     */
    function list721Asset(
        address collection,
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external;

    /**
     * @dev Creates an asset with erc1155 implementation
     * @param collection, Address of the asset collection
     * @param owner, initial owner of asset
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param apr, annual percentage rate for calculating rewards
     * @param dueDate, end date for calculating rewards
     * @dev Needs admin access to create an asset
     */
    function list1155Asset(
        address collection,
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external;

    /**
     * @dev Creates an asset with its parameters
     * @param owner, initial owner of asset
     * @param assetId, unique identifier of asset
     * @param price, asset price to sell
     * @param dueDate, end date for calculating rewards
     * @param apr, annual percentage rate for calculating rewards
     * @dev Needs admin access to create an asset
     */
    function createAsset(
        address owner,
        uint256 assetId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external;

    /**
     * @dev Creates batch asset with their parameters
     * @param owners, initial owners of assets
     * @param assetIds, unique identifiers of assets
     * @param prices, assets price to sell
     * @param dueDates, end dates for calculating rewards
     * @param aprs, annual percentage rates for calculating rewards
     * @dev Needs admin access to batch create asset
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata assetIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates
    ) external;

    /**
     * @dev Settles an asset after due date and claim remaining rewards for the owner
     * @dev Transfer back the asset and transfers the price to current owner
     * @dev Transfer price to current owner
     * @dev Deletes the stored parameters
     * @param collection, Address of the asset collection
     * @param assetId, unique number of the asset
     */
    function settleAsset(address collection, uint256 assetId) external;

    /**
     * @dev Changes owner to buyer
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @param collection, Address of the asset collection
     * @param assetId, unique number of the asset
     */
    function buy(address collection, uint256 assetId) external;

    /**
     * @dev Batch buy assets from owners
     * @dev Loop through arrays and calls the buy function
     * @param collections, Addresses of the asset collections
     * @param assetIds, unique identifiers of the assets
     */
    function batchBuy(
        address[] calldata collections,
        uint256[] calldata assetIds
    ) external;

    /**
     * @dev Relist an asset for the current owner
     * @param collection, Address of the asset collection
     * @param assetId, unique identifier of the asset
     * @param salePrice, new price for asset sale
     */
    function relist(
        address collection,
        uint256 assetId,
        uint256 salePrice
    ) external;

    /**
     * @dev claim available rewards for current owner
     * @dev updates lastClaimDate for the asset in the asset contract
     * @dev Caller should own the assetId
     * @param collection, Address of the asset collection
     * @param assetId, unique number of the asset
     */
    function claimReward(address collection, uint256 assetId) external;

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
     * @param assetId, asset id to buy
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
        uint256 assetId,
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
     * @return address, Address of the stable token contract
     */
    function getStableToken() external view returns (address);

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
     * @param collection, Address of the asset collection
     * @param assetId, unique identifier of asset
     * @return reward the rewards Amount
     */
    function getRemainingReward(
        address collection,
        uint256 assetId
    ) external view returns (uint256 reward);

    /**
     * @dev Calculates available rewards to claim
     * @param collection, Address of the asset collection
     * @param assetId, unique identifier of asset
     * @return reward the accumulated rewards amount for the current owner
     */
    function getAvailableReward(
        address collection,
        uint256 assetId
    ) external view returns (uint256 reward);

    /**
     * @dev Gets the asset information
     * @param collection, Address of the asset collection
     * @param assetId, unique identifier of asset
     * @return assetInfo struct
     */
    function getAssetInfo(
        address collection,
        uint256 assetId
    ) external view returns (AssetInfo memory);
}
