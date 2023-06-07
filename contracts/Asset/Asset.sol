// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "contracts/Marketplace/interface/IMarketplace.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "contracts/Asset/interface/IAsset.sol";

/**
 * @title The asset contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of asset and rewards distribution
 */
contract Asset is Context, ERC165, IAsset, DLT, AccessControl {
    using ERC165Checker for address;

    // Create a new role identifier for the marketplace role
    bytes32 public constant MARKETPLACE_ROLE =
        0x0ea61da3a8a09ad801432653699f8c1860b1ae9d2ea4a141fadfd63227717bc8;

    string private _assetBaseURI;
    uint256 private constant _YEAR = 365 days;

    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

    /**
     * @dev Mapping will be indexing the AssetInfo for each asset category by its mainId
     */
    mapping(uint256 => AssetInfo) private _assets;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI_
    ) DLT(name, symbol) {
        _setBaseURI(baseURI_);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IAsset-createAsset}.
     */
    function createAsset(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 apr,
        uint256 dueDate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _createAsset(owner, mainId, price, dueDate, apr);
    }

    /**
     * @dev See {IAsset-settleAsset}.
     */
    function settleAsset(
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) returns (uint256 price) {
        if (!_msgSender().supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();
        AssetInfo memory asset = _assets[mainId];

        require(block.timestamp > asset.dueDate, "Due date not passed");

        price = asset.price;
        _burn(asset.owner, mainId, 1, 1);
        delete _assets[mainId];
    }

    /**
     * @dev See {IAsset-batchCreateAsset}.
     */
    function batchCreateAsset(
        address[] calldata owners,
        uint256[] calldata mainIds,
        uint256[] calldata prices,
        uint256[] calldata aprs,
        uint256[] calldata dueDates
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            owners.length == mainIds.length &&
                owners.length == prices.length &&
                owners.length == dueDates.length &&
                owners.length == aprs.length,
            "No array parity"
        );

        for (uint256 i = 0; i < mainIds.length; ) {
            _createAsset(
                owners[i],
                mainIds[i],
                prices[i],
                dueDates[i],
                aprs[i]
            );

            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev See {IAsset-setBaseURI}.
     */
    function setBaseURI(
        string calldata newBaseURI
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(newBaseURI);
    }

    /**
     * @dev See {IAsset-changeOwner}.
     */
    function changeOwner(
        address newOwner,
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) {
        if (!_msgSender().supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();

        AssetInfo storage asset = _assets[mainId];

        asset.salePrice = 0;
        asset.owner = newOwner;
    }

    /**
     * @dev See {IAsset-updateClaim}.
     */
    function updateClaim(
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) returns (uint256 reward) {
        if (!_msgSender().supportsInterface(_MARKETPLACE_INTERFACE_ID))
            revert UnsupportedInterface();
        AssetInfo storage asset = _assets[mainId];

        reward = _getAvailableReward(mainId);

        asset.lastClaimDate = (
            block.timestamp > asset.dueDate ? asset.dueDate : block.timestamp
        );
    }

    /**
     * @dev See {IAsset-relist}.
     */
    function relist(
        uint256 mainId,
        uint256 salePrice
    ) external onlyRole(MARKETPLACE_ROLE) {
        _assets[mainId].salePrice = salePrice;
        _approve(_assets[mainId].owner, _msgSender(), mainId, 1, 1);
    }

    /**
     * @dev See {IAsset-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 reward) {
        AssetInfo memory asset = _assets[mainId];
        uint256 tenure;

        if (asset.lastClaimDate != 0) {
            tenure = asset.dueDate - asset.lastClaimDate;
        } else if (asset.price != 0) {
            tenure =
                asset.dueDate -
                (
                    block.timestamp > asset.dueDate
                        ? asset.dueDate
                        : block.timestamp
                );
        }
        reward = _calculateFormula(asset.price, tenure, asset.rewardApr);
    }

    /**
     * @dev See {IAsset-getAvailableReward}.
     */
    function getAvailableReward(
        uint256 mainId
    ) external view returns (uint256) {
        return _getAvailableReward(mainId);
    }

    /**
     * @dev See {IAsset-getAssetInfo}.
     */
    function getAssetInfo(
        uint256 mainId
    ) external view returns (AssetInfo memory) {
        return _assets[mainId];
    }

    /**
     * @dev See {IAsset-tokenURI}.
     */
    function tokenURI(uint256 mainId) external view returns (string memory) {
        string memory stringAssetNumber = Strings.toString(mainId);
        return string.concat(_assetBaseURI, stringAssetNumber);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, AccessControl) returns (bool) {
        return
            interfaceId == type(IAsset).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Changes the asset base URI
     * @param newBaseURI, String of the asset base URI
     */
    function _setBaseURI(string memory newBaseURI) private {
        string memory oldBaseURI = _assetBaseURI;
        _assetBaseURI = newBaseURI;
        emit AssetBaseURISet(oldBaseURI, newBaseURI);
    }

    /**
     * @dev Creates a new asset with given mainId and transfer it to owner
     * @param owner, Address of the initial asset owner
     * @param mainId, unique identifier of asset
     * @param price, asset price to buy
     * @param dueDate, is the end date for caluclating rewards
     * @param apr, is the annual percentage rate for calculating rewards
     */
    function _createAsset(
        address owner,
        uint256 mainId,
        uint256 price,
        uint256 dueDate,
        uint256 apr
    ) private {
        require(owner != address(0), "Invalid owner address");
        require(mainTotalSupply(mainId) == 0, "Already minted");
        _assets[mainId] = AssetInfo(owner, price, price, apr, dueDate, 0);
        _mint(owner, mainId, 1, 1);

        emit AssetCreated(_msgSender(), owner, mainId);
    }

    /**
     * @dev Calculates accumulated rewards based on rewardApr if the asset has an owner
     * @param mainId, unique identifier of asset
     * @return reward , accumulated rewards for the current owner
     */
    function _getAvailableReward(
        uint256 mainId
    ) private view returns (uint256 reward) {
        AssetInfo memory asset = _assets[mainId];

        if (asset.lastClaimDate != 0) {
            uint256 tenure = (
                block.timestamp > asset.dueDate
                    ? asset.dueDate
                    : block.timestamp
            ) - asset.lastClaimDate;

            reward = _calculateFormula(asset.price, tenure, asset.rewardApr);
        }
    }

    /**
     * @dev Calculates the rewards for a given asset
     * @param price is the price of asset
     * @param tenure is the duration from last updated rewards
     * @param apr is the annual percentage rate of rewards for assets
     */
    function _calculateFormula(
        uint256 price,
        uint256 tenure,
        uint256 apr
    ) private pure returns (uint256) {
        return ((price * tenure * apr) / 1e4) / _YEAR;
    }
}
