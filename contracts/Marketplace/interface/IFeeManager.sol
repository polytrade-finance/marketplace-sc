// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { GenericErrors } from "contracts/lib/errors.sol";

/**
 * @title The main interface to define the fee manager
 * @author Polytrade.Finance
 * @dev Collection of all procedures related to the fee manager
 */

interface IFeeManager is GenericErrors {
    /**
     * @dev Emitted when a new initial fee set
     * @dev initial fee applies to the first buy
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @param oldFee, old initial fee percentage
     * @param newFee, old initial fee percentage
     */
    event InitialFeeChanged(
        uint256 mainId,
        uint256 subId,
        uint256 oldFee,
        uint256 newFee
    );

    /**
     * @dev Emitted when a new buying fee set
     * @dev buying fee applies to the all buys but the first one
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @param oldFee, old buying fee percentage
     * @param newFee, old buying fee percentage
     */
    event BuyingFeeChanged(
        uint256 mainId,
        uint256 subId,
        uint256 oldFee,
        uint256 newFee
    );

    /**
     * @dev Emitted when new `Fee Wallet` has been set
     * @param oldFeeWallet, Address of the old fee wallet
     * @param newFeeWallet, Address of the new fee wallet
     */
    event FeeWalletSet(address oldFeeWallet, address newFeeWallet);

    /**
     * @dev Emitted when new default initial and buying fees set
     * @param oldInitialFee, old initial fee percentage
     * @param oldBuyingFee, old buying fee percentage
     * @param newInitialFee, new initial fee percentage
     * @param newBuyingFee, new buying fee percentage
     */
    event DefaultFeesChanged(
        uint256 oldInitialFee,
        uint256 oldBuyingFee,
        uint256 newInitialFee,
        uint256 newBuyingFee
    );

    error InvalidFee();

    function setDefaultFees(
        uint256 defaultInitialFee,
        uint256 defaultBuyingFee
    ) external;

    /**
     * @dev Set new initial fee for specific mainId and subId
     * @dev Initial fee applies to the first buy
     * @dev Needs admin access to set
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @param initialFee, new initial fee percentage with 2 decimals
     */
    function setInitialFee(
        uint256 mainId,
        uint256 subId,
        uint256 initialFee
    ) external;

    /**
     * @dev Set new buying fee
     * @dev Buying fee applies to all buys but first one
     * @dev Needs admin access to set
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @param buyingFee, new buying fee percentage with 2 decimals
     */
    function setBuyingFee(
        uint256 mainId,
        uint256 subId,
        uint256 buyingFee
    ) external;

    /**
     * @dev Set new initial fee for specific mainId and subId
     * @dev Initial fee applies to the first buy
     * @dev Needs admin access to set
     * @param mainIds, main identifiers of the asset
     * @param subIds, property identifiers of main asset
     * @param initialFees, new initial fees percentage with 2 decimals
     */
    function batchSetInitialFee(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata initialFees
    ) external;

    /**
     * @dev Set new buying fee
     * @dev Buying fee applies to all buys but first one
     * @dev Needs admin access to set
     * @param mainIds, main identifiers of the asset
     * @param subIds, property identifiers of main asset
     * @param buyingFees, new buying fees percentage with 2 decimals
     */
    function batchSetBuyingFee(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata buyingFees
    ) external;

    /**
     * @dev Allows to set a new fee wallet address where buying fees will be allocated.
     * @param newFeeWallet, Address of the new fee wallet
     */
    function setFeeWallet(address newFeeWallet) external;

    /**
     * @dev Gets current fee wallet address
     * @return address Address of the fee wallet
     */
    function getFeeWallet() external view returns (address);

    /**
     * @dev Gets initial fee percentage that applies to first buys
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @return percentage of initial fee with 2 decimals
     */
    function getInitialFee(
        uint256 mainId,
        uint256 subId
    ) external view returns (uint256);

    /**
     * @dev Gets buying fee percentage that applies to all the buys except first one
     * @param mainId, main identifier of the asset
     * @param subId, property identifier of main asset
     * @return percentage of buying fee with 2 decimals
     */
    function getBuyingFee(
        uint256 mainId,
        uint256 subId
    ) external view returns (uint256);

    /**
     * @dev Gets default buying fee percentage that applies to all first buys
     * @return percentage of buying fee with 2 decimals
     */
    function getDefaultInitialFee() external view returns (uint256);

    /**
     * @dev Gets default initial fee percentage that applies to all the buys except first one
     * @return percentage of buying fee with 2 decimals
     */
    function getDefaultBuyingFee() external view returns (uint256);
}
