// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { PropertyInfo, IPropertyAsset } from "contracts/Asset/interface/IPropertyAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { IToken } from "contracts/Token/interface/IToken.sol";
import { IMarketplace } from "contracts/Marketplace/interface/IMarketplace.sol";

/**
 * @title The property asset contract based on EIP6960
 * @author Polytrade.Finance
 */
contract PropertyAsset is
    Initializable,
    Context,
    AccessControl,
    IPropertyAsset
{
    using SafeERC20 for IToken;
    using ERC165Checker for address;

    IBaseAsset private _assetCollection;
    IMarketplace private _marketplace;
    IToken private _stableToken;

    mapping(uint256 => mapping(uint256 => PropertyInfo)) private _propertyInfo;

    // Create a new role identifier for the asset originator
    bytes32 public constant ASSET_ORIGINATOR =
        0x6515eccc42cea4c6b51e4cf769f86c1580ce4efeb1d5bee305af7f36bbb6ce6e;

    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;

    /**
     * @dev Initializer for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     * @param tokenAddress_, Address of the ERC20 token address
     */
    function initialize(
        address marketplace_,
        address assetCollection_,
        address tokenAddress_
    ) external initializer {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        if (!marketplace_.supportsInterface(_MARKETPLACE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        require(tokenAddress_ != address(0), "Invalid address");

        _assetCollection = IBaseAsset(assetCollection_);
        _marketplace = IMarketplace(marketplace_);
        _stableToken = IToken(tokenAddress_);

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ASSET_ORIGINATOR, _msgSender());
    }

    /**
     * @dev See {IPropertyAsset-createProperty}.
     */
    function createProperty(
        address owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        PropertyInfo calldata propertyInfo
    ) external onlyRole(ASSET_ORIGINATOR) {
        _createProperty(owner, propertyMainId, propertySubId, propertyInfo);
    }

    /**
     * @dev See {IPropertyAsset-batchCreateProperty}.
     */
    function batchCreateProperty(
        address[] calldata owners,
        uint256[] calldata propertyMainIds,
        uint256[] calldata propertySubIds,
        PropertyInfo[] calldata propertyInfos
    ) external onlyRole(ASSET_ORIGINATOR) {
        uint256 length = owners.length;
        require(
            propertyMainIds.length == length &&
                length == propertyInfos.length &&
                length == propertySubIds.length,
            "No array parity"
        );

        for (uint256 i = 0; i < length; ) {
            _createProperty(
                owners[i],
                propertyMainIds[i],
                propertySubIds[i],
                propertyInfos[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IPropertyAsset-settleProperty}.
     */
    function settleProperty(
        uint256 propertyMainId,
        uint256 propertySubId,
        uint256 settlePrice,
        address owner
    ) external onlyRole(ASSET_ORIGINATOR) {
        _settleProperty(settlePrice, propertyMainId, propertySubId, owner);
    }

    /**
     * @dev See {IPropertyAsset-batchSettleProperty}.
     */
    function batchSettleProperty(
        uint256[] calldata propertyMainIds,
        uint256[] calldata propertySubIds,
        uint256[] calldata settlePrices,
        address[] calldata owners
    ) external onlyRole(ASSET_ORIGINATOR) {
        uint256 length = propertyMainIds.length;
        require(
            owners.length == length &&
                length == propertySubIds.length &&
                length == settlePrices.length,
            "No array parity"
        );
        for (uint256 i = 0; i < length; ) {
            _settleProperty(
                settlePrices[i],
                propertyMainIds[i],
                propertySubIds[i],
                owners[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IPropertyAsset-burnProperty}.
     */
    function burnProperty(
        address owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _assetCollection.burnAsset(
            owner,
            propertyMainId,
            propertySubId,
            amount
        );

        uint256 totalSubSupply = _assetCollection.totalSubSupply(
            propertyMainId,
            propertySubId
        );

        _propertyInfo[propertyMainId][propertySubId].fractions = totalSubSupply;

        if (totalSubSupply == 0) {
            delete _propertyInfo[propertyMainId][propertySubId];
        }
    }

    function getPropertyInfo(
        uint256 propertyMainId,
        uint256 propertySubId
    ) external view returns (PropertyInfo memory) {
        return _propertyInfo[propertyMainId][propertySubId];
    }

    /**
     * @dev Called in settleProperty and batchSettleProperty functions
     * @param propertyMainId, unique identifier of property
     * @param propertySubId, unique identifier of property
     * @param owner, address of the owner for settlement
     */
    function _settleProperty(
        uint256 settlePrice,
        uint256 propertyMainId,
        uint256 propertySubId,
        address owner
    ) private {
        PropertyInfo memory property = _propertyInfo[propertyMainId][
            propertySubId
        ];
        uint256 subBalanceOf = _assetCollection.subBalanceOf(
            owner,
            propertyMainId,
            propertySubId
        );

        require(settlePrice != 0, "Invalid settle amount");
        require(property.dueDate != 0, "Invalid property id");
        require(subBalanceOf != 0, "Not enough balance");
        require(block.timestamp > property.dueDate, "Due date not passed");

        settlePrice = (settlePrice * subBalanceOf) / property.fractions;
        _assetCollection.burnAsset(
            owner,
            propertyMainId,
            propertySubId,
            subBalanceOf
        );
        _stableToken.safeTransferFrom(
            _marketplace.getTreasuryWallet(),
            owner,
            settlePrice
        );
        if (
            _assetCollection.totalSubSupply(propertyMainId, propertySubId) == 0
        ) {
            delete _propertyInfo[propertyMainId][propertySubId];
        }

        emit PropertySettled(owner, propertyMainId, propertySubId, settlePrice);
    }

    /**
     * @dev Called in createProperty and batchCreateProperty functions
     * @param owner, initial owner of property
     * @param propertyMainId, unique identifier of property
     * @param propertySubId, unique identifier of property
     * @param propertyInfo, related information for the property
     */
    function _createProperty(
        address owner,
        uint256 propertyMainId,
        uint256 propertySubId,
        PropertyInfo calldata propertyInfo
    ) private {
        require(
            _assetCollection.totalSubSupply(propertyMainId, propertySubId) == 0,
            "Property already created"
        );

        _propertyInfo[propertyMainId][propertySubId] = propertyInfo;
        _assetCollection.createAsset(
            owner,
            propertyMainId,
            propertySubId,
            propertyInfo.fractions
        );
    }
}
