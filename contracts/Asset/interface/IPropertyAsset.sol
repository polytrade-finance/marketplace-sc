// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PropertyInfo, IToken } from "contracts/lib/structs.sol";

interface IPropertyAsset {
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
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param propertyMainId, propertyMainId identifier
     * @param settlePrice, paid amount for settlement
     * @param token, address of token used for settlement
     */
    event PropertySettled(
        address indexed owner,
        uint256 propertyMainId,
        uint256 settlePrice,
        address token
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Allows to set a new treasury wallet address where funds will be allocated.
     * @param newTreasuryWallet, Address of the new treasury wallet
     */
    function setTreasuryWallet(address newTreasuryWallet) external;

    /**
     * @dev Creates an property with its parameters
     * @param owner, address of the initial owner
     * @param propertyInfo, all related property information
     * @dev Needs asset originator access to create an property
     */
    function createProperty(
        address owner,
        PropertyInfo calldata propertyInfo
    ) external returns (uint256);

    /**
     * @dev Batch creates properties with their parameters
     * @param owners, addresses of the initial owners
     * @param propertyInfos, all related properties information
     * @dev Needs asset originator access to create an property
     */
    function batchCreateProperty(
        address[] calldata owners,
        PropertyInfo[] calldata propertyInfos
    ) external returns (uint256[] memory);

    /**
     * @dev Settle an property for the a specific owner
     * @param propertyMainId, unique identifier of property
     * @param settlePrice, settlement price
     * @param owner, address of specified owner
     * @dev Needs asset originator access to settle an property
     */
    function settleProperty(
        uint256 propertyMainId,
        uint256 settlePrice,
        address owner
    ) external;

    /**
     * @dev Settle properties for the specified owners
     * @param propertyMainIds, unique identifiers of properties
     * @param settlePrices, settlement prices
     * @param owners, address of specified owners
     * @dev Needs asset originator access to settle an property
     */
    function batchSettleProperty(
        uint256[] calldata propertyMainIds,
        uint256[] calldata settlePrices,
        address[] calldata owners
    ) external;

    /**
     * @dev Burns an property with its parameters
     * @param propertyMainId, unique identifier of property
     * @dev Needs admin access to burn an property
     */
    function burnProperty(
        address owner,
        uint256 propertyMainId,
        uint256 amount
    ) external;

    /**
     * @dev Gets current treasury wallet address
     * @return address, Address of the treasury wallet
     */
    function getTreasuryWallet() external view returns (address);

    /**
     * @dev Gets the property information
     * @param propertyMainId, unique identifier of property
     * @return propertyInfo struct
     */
    function getPropertyInfo(
        uint256 propertyMainId
    ) external view returns (PropertyInfo memory);
}
