// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title The main interface to define the main marketplace
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the marketplace
 */
interface IMarketplace {
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
     * @param oldOwner, Address of the previous owner
     * @param newOwner, Address of the new owner
     * @param id, idof the bought asset
     */
    event AssetBought(
        address indexed oldOwner,
        address indexed newOwner,
        uint256 id
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
     * @param assetId, unique number of the asset
     */
    event AssetSettled(address indexed owner, uint256 assetId);

    /**
     * @dev Emitted when an asset is settled
     * @param assetId, unique number of the asset
     * @param salePrice, unique number of the asset
     */
    event AssetRelisted(uint256 assetId, uint256 salePrice);

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Settles an asset after due date and claim remaining rewards for the owner
     * @dev call `settleasset` function from asset collection
     * @dev Burns the asset and transfers the price to current owner
     * @param assetId, unique number of the asset
     */
    function settleAsset(uint256 assetId) external;

    /**
     * @dev Transfer asset to buyer and price to treasuryWallet also deducts fee from buyer
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @dev Automatically claims rewards for prevoius owner
     * @param assetId, unique number of the asset
     */
    function buy(uint256 assetId) external;

    /**
     * @dev Batch buy assets from owners
     * @dev Loop through arrays and calls the buy function
     * @param assetIds, unique identifiers of the assets
     */
    function batchBuy(uint[] calldata assetIds) external;

    /**
     * @dev Relist an asset by current owner
     * @param assetId, unique identifier of the asset
     * @param salePrice, new price for asset sale
     */
    function relist(uint256 assetId, uint256 salePrice) external;

    /**
     * @dev claim available rewards for current owner
     * @dev updates lastClaimDate for the asset in the asset contract
     * @dev Caller should own the assetId
     * @param assetId, unique number of the asset
     */
    function claimReward(uint256 assetId) external;

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
}
