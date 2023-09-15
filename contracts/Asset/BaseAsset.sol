// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {DLTEnumerable} from "dual-layer-token/contracts/DLT/extensions/DLTEnumerable.sol";
import {DLTPermit} from "dual-layer-token/contracts/DLT/extensions/DLTPermit.sol";
import {ERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {DLT} from "dual-layer-token/contracts/DLT/DLT.sol";
import {AssetInfo, IBaseAsset} from "contracts/Asset/interface/IBaseAsset.sol";

/**
 * @title The asset contract based on EIP6960
 * @author Polytrade.Finance
 * @dev Manages creation of asset and rewards distribution
 */
contract BaseAsset is Context, ERC165, DLT, DLTEnumerable, DLTPermit, AccessControl, IBaseAsset {

    // Create a new role identifier for the marketplace role
    bytes32 public constant ASSET_MANAGER = 0x9c6e3ae929b539a99db03120eac7d9f862d68479b44f1eec05ab6036fcf56830;

    // Create a new role identifier for the marketplace role
    bytes32 public constant MARKETPLACE_ROLE = 0x0ea61da3a8a09ad801432653699f8c1860b1ae9d2ea4a141fadfd63227717bc8;

    mapping(uint256 => mapping(uint256 => AssetInfo)) private _assetInfo;
    mapping(uint256 => string) private _assetBaseURI;

    constructor(string memory name, string memory symbol, string memory version, string memory baseURI_)
        DLT(name, symbol)
        DLTPermit(name, version)
    {
        _setBaseURI(1, baseURI_);
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @dev See {IBaseAsset-updatePurchaseDate}.
     */
    function updatePurchaseDate(uint256 mainId, uint256 subId) external onlyRole(MARKETPLACE_ROLE) {
        _assetInfo[mainId][subId].purchaseDate = block.timestamp;
    }

    /**
     * @dev See {IBaseAsset-createAsset}.
     */
    function createAsset(address owner, uint256 mainId, uint256 subId, uint256 amount)
        external
        onlyRole(ASSET_MANAGER)
    {
        _assetInfo[mainId][subId].initialOwner = owner;
        _mint(owner, mainId, subId, amount);
        emit AssetCreated(owner, mainId, subId, amount);
    }

    /**
     * @dev See {IBaseAsset-burnAsset}.
     */
    function burnAsset(address owner, uint256 mainId, uint256 subId, uint256 amount) external onlyRole(ASSET_MANAGER) {
        _burn(owner, mainId, subId, amount);
        emit AssetBurnt(owner, mainId, subId, amount);
    }

    /**
     * @dev See {IBaseAsset-setBaseURI}.
     */
    function setBaseURI(uint256 mainId, string calldata newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setBaseURI(mainId, newBaseURI);
    }

    /**
     * @dev See {IBaseAsset-tokenURI}.
     */
    function tokenURI(uint256 mainId, uint256 subId) external view returns (string memory) {
        string memory stringAssetSubId = Strings.toString(subId);
        return string.concat(_assetBaseURI[mainId], stringAssetSubId);
    }

    function getAssetInfo(uint256 mainId, uint256 subId) external view returns (AssetInfo memory) {
        return _assetInfo[mainId][subId];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, AccessControl) returns (bool) {
        return interfaceId == type(IBaseAsset).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {DLT-_mint}.
     */
    function _mint(address recipient, uint256 mainId, uint256 subId, uint256 amount)
        internal
        virtual
        override(DLT, DLTEnumerable)
    {
        super._mint(recipient, mainId, subId, amount);
    }

    /**
     * @dev See {DLT-_burn}.
     */
    function _burn(address recipient, uint256 mainId, uint256 subId, uint256 amount)
        internal
        virtual
        override(DLT, DLTEnumerable)
    {
        super._burn(recipient, mainId, subId, amount);
    }

    /**
     * @dev Changes the asset base URI
     * @param newBaseURI, String of the asset base URI
     */
    function _setBaseURI(uint256 mainId, string memory newBaseURI) private {
        string memory oldBaseURI = _assetBaseURI[mainId];
        _assetBaseURI[mainId] = newBaseURI;
        emit AssetBaseURISet(mainId, oldBaseURI, newBaseURI);
    }
}
