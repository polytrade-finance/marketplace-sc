// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interface/IDLT.sol";

interface IAsset is IDLT {
    /**
     * @title A new struct to define the asset information
     * @param Price, is the price of asset
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
     * @dev Emitted when `newURI` is set to the assets instead of `oldURI`
     * @param oldBaseURI, Old base URI for the assets
     * @param newBaseURI, New base URI for the assets
     */
    event AssetBaseURISet(string oldBaseURI, string newBaseURI);

    /**
     * @dev Emitted when an asset is created with it's parameters for an owner
     * @param creator, Address of the asset creator
     * @param owner, Address of the initial onvoice owner
     * @param mainId, mainId is the unique identifier of asset
     */
    event AssetCreated(
        address indexed creator,
        address indexed owner,
        uint256 indexed mainId
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Settles asset for owner and burn the asset
     * @param mainId, unique identifier of asset
     * @dev Needs marketplace access to settle an asset
     * @return the asset price
     */
    function settleAsset(uint256 mainId) external returns (uint256);

    /**
     * @dev Creates an asset with its parameters
     * @param owner, initial owner of asset
     * @param mainId, unique identifier of asset
     * @param price, asset price to sell
     * @param dueDate, end date for calculating rewards
     * @param apr, annual percentage rate for calculating rewards
     * @dev Needs marketplace access to create an asset
     */
    function createAsset(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) external;

    /**
     * @dev Relist an asset by marketplace
     * @param mainId, unique identifier of asset
     * @param salePrice, New price for sale
     * @dev Needs marketplace access to relist an asset
     */
    function relist(uint256 mainId, uint256 salePrice) external;

    /**
     * @dev Set a new baseURI for assets
     * @dev Needs admin access to schange base URI
     * @param newBaseURI, string value of new URI
     */
    function setBaseURI(string calldata newBaseURI) external;

    /**
     * @dev Updates lastClaimDate whenever a buy or claimReward happens from marketplace
     * @dev Needs marketplace access to claim
     * @param mainId, unique identifier of asset
     * @return reward , accumulated rewards for the current owner
     */
    function updateClaim(uint256 mainId) external returns (uint256 reward);

    /**
     * @dev Calculates the remaning reward
     * @param mainId, unique identifier of asset
     * @return reward the rewards Amount
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 reward);

    /**
     * @dev Calculates available rewards to claim
     * @param mainId, unique identifier of asset
     * @return reward the accumulated rewards amount for the current owner
     */
    function getAvailableReward(
        uint256 mainId
    ) external view returns (uint256 reward);

    /**
     * @dev Gets the asset information
     * @param mainId, unique identifier of asset
     * @return assetInfo struct
     */
    function getAssetInfo(
        uint256 mainId
    ) external view returns (AssetInfo calldata);

    /**
     * @dev concatenate asset id (mainId) to baseURI
     * @param mainId, unique identifier of asset
     * @return string value of asset URI
     */
    function tokenURI(uint256 mainId) external view returns (string memory);
}
