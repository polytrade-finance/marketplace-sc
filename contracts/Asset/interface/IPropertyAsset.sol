// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { PropertyInfo } from "contracts/lib/structs.sol";

interface IPropertyAsset {
    /**
     * @dev Emitted when an asset is settled
     * @param owner, address of the asset owner
     * @param propertyMainId, propertyMainId identifier
     * @param propertySubId, unique number of the property
     * @param settlePrice, paid amount for settlement
     */
    event PropertySettled(
        address indexed owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        uint256 settlePrice
    );

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Creates an property with its parameters
     * @param owner, address of the initial owner
     * @param propertyMainId, unique identifier of property
     * @param propertySubId, unique identifier of property
     * @param propertyInfo, all related property information
     * @dev Needs asset originator access to create an property
     */
    function createProperty(
        address owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        PropertyInfo calldata propertyInfo
    ) external;

    function batchCreateProperty(
        address[] calldata owners,
        uint256[] calldata propertyMainIds,
        uint256[] calldata propertySubIds,
        PropertyInfo[] calldata propertyInfos
    ) external;

    function settleProperty(
        uint256 propertyMainId,
        uint256 propertySubId,
        uint256 settlePrice,
        address owner
    ) external;

    function batchSettleProperty(
        uint256[] calldata propertyMainIds,
        uint256[] calldata propertySubIds,
        uint256[] calldata settlePrices,
        address[] calldata owners
    ) external;

    /**
     * @dev Burns an property with its parameters
     * @param propertyMainId, unique identifier of property
     * @param propertySubId, unique identifier of property
     * @dev Needs admin access to burn an property
     */
    function burnProperty(
        address owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        uint256 amount
    ) external;

    /**
     * @dev Gets the property information
     * @param propertyMainId, unique identifier of property
     * @param propertySubId, unique identifier of property
     * @return propertyInfo struct
     */
    function getPropertyInfo(
        uint256 propertyMainId,
        uint256 propertySubId
    ) external view returns (PropertyInfo memory);
}
