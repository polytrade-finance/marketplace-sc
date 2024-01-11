// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ListedInfo, IToken } from "contracts/lib/structs.sol";
import { GenericErrors } from "contracts/lib/errors.sol";

/**
 * @title The main interface to define the main marketplace
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the marketplace
 */

interface IMarketplace is GenericErrors {
    /**
     * @dev Emitted when asset owner changes
     * @param oldOwner, Address of the previous owner
     * @param newOwner, Address of the new owner
     * @param mainId, unique identifiers of the assets
     * @param subId, id of the bought asset
     * @param salePrice, the sale price of whole asset
     * @param payPrice, the price buyer pays that is fraction of salePrice
     * @param fractions, number of bought fractions
     * @param token, address of receiveing token that listed
     */
    event AssetBought(
        address indexed oldOwner,
        address indexed newOwner,
        uint256 mainId,
        uint256 subId,
        uint256 salePrice,
        uint256 payPrice,
        uint256 fractions,
        address token
    );

    /**
     * @dev Emitted when an asset is listed
     * @param owner, address of the asset owner
     * @param mainId, unique identifiers of the assets
     * @param subId, unique identifiers of the asset
     * @param listedInfo, information of listed asset including salePrice, listedFraction, minFraction and token of sale
     */
    event AssetListed(
        address indexed owner,
        uint256 indexed mainId,
        uint256 indexed subId,
        ListedInfo listedInfo
    );

    /**
     * @dev Emitted when an asset is unlisted
     * @param owner, address of the asset owner
     * @param mainId, unique identifiers of the assets
     * @param subId, unique identifiers of the asset
     */
    event AssetUnlisted(
        address indexed owner,
        uint256 indexed mainId,
        uint256 indexed subId
    );

    /**
     * @dev Emitted when new `Fee Manager` has been set
     * @param oldFeeManager, Address of the old fee manager
     * @param newFeeManager, Address of the new fee manager
     */
    event FeeManagerSet(address oldFeeManager, address newFeeManager);

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    error OfferExpired();
    error InvalidOfferor();
    error InvalidSignature();
    error InvalidMinFraction();
    error InvalidFractionToList();
    error InvalidFractionToBuy();
    error NotEnoughListed();

    /**
     * @dev Changes owner to buyer
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @param mainId, unique identifiers of the assets
     * @param subId, unique identifiers of the asset
     * @param fractionToBuy, amount of fraction for buying
     * @param owner, address of the owner of asset
     */
    function buy(
        uint256 mainId,
        uint256 subId,
        uint256 fractionToBuy,
        address owner
    ) external;

    /**
     * @dev Batch buy assets from owners
     * @dev Loop through arrays and calls the buy function
     * @param mainIds, arrray of unique identifiers of the assets
     * @param subIds, array of unique identifiers of the assets
     * @param fractionsToBuy, amounts of fraction for buying
     * @param owners, addresses of the owner of asset
     */
    function batchBuy(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata fractionsToBuy,
        address[] calldata owners
    ) external;

    /**
     * @dev List an asset for the current owner
     * @param mainId, unique identifiers of the assets
     * @param subId, unique identifier of the asset
     * @param listedInfo, information of listed asset including salePrice, listedFraction, minFraction and token of sale
     */
    function list(
        uint256 mainId,
        uint256 subId,
        ListedInfo calldata listedInfo
    ) external;

    /**
     * @dev Batch list assets for the specified owners
     * @param mainIds, main unique identifier the asset
     * @param subIds, sub unique identifier of the asset
     * @param listedInfos, information of listed asset including salePrice, listedFraction, minFraction and token sale
     */
    function batchList(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        ListedInfo[] calldata listedInfos
    ) external;

    /**
     * @dev Unlist an asset for the current owner
     * @param mainId, unique identifiers of the assets
     * @param subId, unique identifier of the asset
     */
    function unlist(uint256 mainId, uint256 subId) external;

    /**
     * @dev Batch unlist assets for the specified owners
     * @param mainIds, main unique identifier the asset
     * @param subIds, sub unique identifier of the asset
     */
    function batchUnlist(
        uint256[] calldata mainIds,
        uint256[] calldata subIds
    ) external;

    /**
     * @dev Allows to buy asset with a signed message by owner with agreed sale price
     * @param owner, Address of the owner of asset
     * @param offeror, Address of the offeror
     * @param offerPrice, offered price for buying asset
     * @param mainId, unique identifiers of the assets
     * @param subId, asset id to buy
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
    function offer(
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
    ) external;

    /**
     * @notice Allows to set a new address for the fee manager.
     * @dev Fee manager should support IFeeManager interface
     * @param newFeeManager, Address of the new fee manager
     */
    function setFeeManager(address newFeeManager) external;

    /**
     * @dev Gets current fee manager address
     * @return address, Address of the fee manager contract
     */
    function getFeeManager() external view returns (address);

    /**
     * @dev Gets current asset collection address
     * @return address, Address of the invocie collection contract
     */
    function getAssetCollection() external view returns (address);

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {offer}.
     *
     * Every successful call to {offer} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times
     */
    function getNonce(address owner) external view returns (uint256);

    /**
     * @dev Gets the domain separator used in the encoding of the signature for {offer}, as defined by {EIP712}.
     * @return bytes32 of the domain separator
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @dev Gets the asset information
     * @param owner, address of the owner
     * @param assetMainId, unique identifier of asset
     * @param assetSubId, unique identifier of asset
     * @return ListedInfo struct
     */
    function getListedInfo(
        address owner,
        uint256 assetMainId,
        uint256 assetSubId
    ) external view returns (ListedInfo memory);
}
