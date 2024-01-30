// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IFeeManager } from "contracts/Marketplace/interface/IFeeManager.sol";

/**
 * @title The fee manager for the marketplace
 * @author Polytrade.Finance
 */
contract FeeManager is ERC165, AccessControl, IFeeManager {
    uint256 private _defaultInitialFee;
    uint256 private _defaultBuyingFee;
    address private _feeWallet;

    mapping(uint256 => mapping(uint256 => uint256)) private _initialFees;
    mapping(uint256 => mapping(uint256 => uint256)) private _buyingFees;

    constructor(
        uint256 defaultInitialFee_,
        uint256 defaultBuyingFee_,
        address feeWallet_
    ) {
        _defaultInitialFee = defaultInitialFee_;
        _defaultBuyingFee = defaultBuyingFee_;

        _setFeeWallet(feeWallet_);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IFeeManager-setDefaultFees}.
     */
    function setDefaultFees(
        uint256 defaultInitialFee,
        uint256 defaultBuyingFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (defaultInitialFee > 10000 || defaultBuyingFee > 10000) {
            revert InvalidFee();
        }
        emit DefaultFeesChanged(
            _defaultInitialFee,
            _defaultBuyingFee,
            defaultInitialFee,
            defaultBuyingFee
        );

        _defaultInitialFee = defaultInitialFee;
        _defaultBuyingFee = defaultBuyingFee;
    }

    /**
     * @dev See {IFeeManager-setInitialFee}.
     */
    function setInitialFee(
        uint256 mainId,
        uint256 subId,
        uint256 initialFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setInitialFee(mainId, subId, initialFee);
    }

    /**
     * @dev See {IFeeManager-setBuyingFee}.
     */
    function setBuyingFee(
        uint256 mainId,
        uint256 subId,
        uint256 buyingFee
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBuyingFee(mainId, subId, buyingFee);
    }

    /**
     * @dev See {IFeeManager-batchSetInitialFee}.
     */
    function batchSetInitialFee(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata initialFees
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = mainIds.length;
        if (subIds.length != length || length != initialFees.length) {
            revert NoArrayParity();
        }
        for (uint256 i = 0; i < length; ) {
            _setInitialFee(mainIds[i], subIds[i], initialFees[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IFeeManager-batchSetBuyingFee}.
     */
    function batchSetBuyingFee(
        uint256[] calldata mainIds,
        uint256[] calldata subIds,
        uint256[] calldata buyingFees
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 length = mainIds.length;
        if (subIds.length != length || length != buyingFees.length) {
            revert NoArrayParity();
        }
        for (uint256 i = 0; i < length; ) {
            _setBuyingFee(mainIds[i], subIds[i], buyingFees[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IFeeManager-setFeeWallet}.
     */
    function setFeeWallet(
        address newFeeWallet
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setFeeWallet(newFeeWallet);
    }

    /**
     * @dev See {IFeeManager-getDefaultInitialFee}.
     */
    function getDefaultInitialFee() external view returns (uint256) {
        return _defaultInitialFee;
    }

    /**
     * @dev See {IFeeManager-getDefaultBuyingFee}.
     */
    function getDefaultBuyingFee() external view returns (uint256) {
        return _defaultBuyingFee;
    }

    /**
     * @dev See {IFeeManager-getInitialFee}.
     */
    function getInitialFee(
        uint256 mainId,
        uint256 subId
    ) external view returns (uint256) {
        return
            _initialFees[mainId][subId] == 0
                ? _defaultInitialFee
                : _initialFees[mainId][subId];
    }

    /**
     * @dev See {IFeeManager-getBuyingFee}.
     */
    function getBuyingFee(
        uint256 mainId,
        uint256 subId
    ) external view returns (uint256) {
        return
            _buyingFees[mainId][subId] == 0
                ? _defaultBuyingFee
                : _buyingFees[mainId][subId];
    }

    /**
     * @dev See {IFeeManager-getFeeWallet}.
     */
    function getFeeWallet() external view returns (address) {
        return _feeWallet;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(IFeeManager).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @notice Allows to set a new address for the fee wallet.
     * @dev Wallet can be EOA or multisig
     * @param newFeeWallet, Address of the new fee wallet
     */
    function _setFeeWallet(address newFeeWallet) private {
        if (newFeeWallet == address(0)) {
            revert InvalidAddress();
        }
        emit FeeWalletSet(_feeWallet, newFeeWallet);
        _feeWallet = newFeeWallet;
    }

    /**
     * @notice Allows to set a new initial fee for a particular asset
     * @param mainId, main identifiers of the asset
     * @param subId, property identifiers of main asset
     * @param initialFee, initial fee with 2 percentage
     */
    function _setInitialFee(
        uint256 mainId,
        uint256 subId,
        uint256 initialFee
    ) private {
        if (initialFee > 10000) {
            revert InvalidFee();
        }

        emit InitialFeeChanged(
            mainId,
            subId,
            _initialFees[mainId][subId],
            initialFee
        );

        _initialFees[mainId][subId] = initialFee;
    }

    /**
     * @notice Allows to set a new buying fee for a particular asset
     * @param mainId, main identifiers of the asset
     * @param subId, property identifiers of main asset
     * @param buyingFee, initial fee with 2 percentage
     */
    function _setBuyingFee(
        uint256 mainId,
        uint256 subId,
        uint256 buyingFee
    ) private {
        if (buyingFee > 10000) {
            revert InvalidFee();
        }

        emit BuyingFeeChanged(
            mainId,
            subId,
            _buyingFees[mainId][subId],
            buyingFee
        );

        _buyingFees[mainId][subId] = buyingFee;
    }
}
