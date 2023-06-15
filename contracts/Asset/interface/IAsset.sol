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
        uint256 price;
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
     * @dev Creates an asset with its parameters
     * @param owner, initial owner of asset
     * @param mainId, unique identifier of asset
     * @param price, asset price to sell
     * @param dueDate, end date for calculating rewards
     * @param apr, annual percentage rate for calculating rewards
     * @dev Needs admin access to create an asset
     */
    function createAsset(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) external;

    /**
     * @dev Creates batch asset with their parameters
     * @param owners, initial owners of assets
     * @param mainIds, unique identifiers of assets
     * @param prices, assets price to sell
     * @param dueDates, end dates for calculating rewards
     * @param aprs, annual percentage rates for calculating rewards
     * @dev Needs admin access to create an asset
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata prices,
        uint256[] calldata dueDates,
        uint256[] calldata aprs
    ) external;

    /**
     * @dev Set a new baseURI for assets
     * @dev Needs admin access to schange base URI
     * @param newBaseURI, string value of new URI
     */
    function setBaseURI(string calldata newBaseURI) external;

    /**
     * @dev Calculates the remaning reward
     * @param mainId, unique identifier of asset
     * @return result the rewards Amount
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 result);

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
