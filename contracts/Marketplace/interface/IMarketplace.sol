// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ListedInfo} from "contracts/lib/structs.sol";
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
    event TreasuryWalletSet(address oldTreasuryWallet, address newTreasuryWallet);

    /**
     * @dev Emitted when new `Fee Wallet` has been set
     * @param oldFeeWallet, Address of the old fee wallet
     * @param newFeeWallet, Address of the new fee wallet
     */
    event FeeWalletSet(address oldFeeWallet, address newFeeWallet);

    /**
     * @dev Emitted when asset owner changes
     * @param oldOwner, Address of the previous owner
     * @param newOwner, Address of the new owner
     * @param mainId, mainId identifies whether its a property or an invoice
     * @param subId, id of the bought asset
     *  @ @param payPrice, the price buyer pays that is fraction of salePrice
     */
    event AssetBought(
        address indexed oldOwner,
        address indexed newOwner,
        uint256 mainId,
        uint256 subId,
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
     * @dev Emitted when an asset is listed
     * @param owner, address of the asset owner
     * @param mainId, mainId identifies whether its a property or an invoice
     * @param subId, unique number of the asset
     * @param salePrice, unique number of the asset
     * @param minFraction, minimum fraction needed to buy
     */
    event AssetListed(
        address indexed owner, uint256 indexed mainId, uint256 indexed subId, uint256 salePrice, uint256 minFraction
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Changes owner to buyer
     * @dev Safe transfer asset to marketplace and transfer the price to treasury wallet if it is the first buy
     * @dev Transfer the price to previous owner if it is not the first buy
     * @dev Owner should have approved marketplace to transfer its assets
     * @dev Buyer should have approved marketplace to transfer its ERC20 tokens to pay price and fees
     * @param mainId, mainId identifies whether its a property or an invoice
     * @param subId, unique number of the asset
     * @param fractionToBuy, amount of fraction for buying
     * @param owner, address of the owner of asset
     */
    function buy(uint256 mainId, uint256 subId, uint256 fractionToBuy, address owner) external;

    /**
     * @dev Batch buy assets from owners
     * @dev Loop through arrays and calls the buy function
     * @param mainIds, arrray of mainIds that identifies whether its a property or an invoice
     * @param subIds, unique identifiers of the assets
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
     * @param mainId, mainId identifies whether its a property or an invoice
     * @param subId, unique identifier of the asset
     * @param salePrice, new price for asset sale
     * @param minFraction, minFraction owner set for buyers
     */
    function list(uint256 mainId, uint256 subId, uint256 salePrice, uint256 minFraction) external;

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
     * @param mainId, mainId identifies whether its a property or an invoice
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
     * @dev Gets the asset information
     * @param owner, address of the owner
     * @param assetMainId, unique identifier of asset
     * @param assetSubId, unique identifier of asset
     * @return ListedInfo struct
     */
    function getListedInfo(address owner, uint256 assetMainId, uint256 assetSubId)
        external
        view
        returns (ListedInfo memory);
}
