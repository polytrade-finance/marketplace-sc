// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "dual-layer-token/contracts/DLT/DLT.sol";
import "contracts/Asset/interface/IAsset.sol";

contract Asset is ERC165, IAsset, DLT, AccessControl {
    string private _assetBaseURI;
    uint256 private constant _YEAR = 365 days;

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
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
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
     * @dev See {IAsset-getRemainingReward}.
     */
    function getRemainingReward(
        uint256 mainId
    ) external view returns (uint256 result) {
        AssetInfo memory asset = _assets[mainId];
        uint256 tenure;

        if (asset.lastClaimDate != 0) {
            tenure = asset.dueDate - asset.lastClaimDate;
            result = _calculateFormula(asset.price, tenure, asset.rewardApr);
        } else if (asset.price != 0) {
            tenure = asset.dueDate - block.timestamp;
            result = _calculateFormula(asset.price, tenure, asset.rewardApr);
        }
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
        require(mainTotalSupply(mainId) == 0, "Asset: Already minted");
        _assets[mainId] = AssetInfo(price, apr, dueDate, 0);
        _mint(owner, mainId, 1, 1);

        emit AssetCreated(msg.sender, owner, mainId);
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
