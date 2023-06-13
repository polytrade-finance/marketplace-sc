// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "dual-layer-token/contracts/DLT/extensions/DLTEnumerable.sol";
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
contract Asset is Context, ERC165, DLT, DLTEnumerable, AccessControl, IAsset {
    using ERC165Checker for address;

    // Create a new role identifier for the marketplace role
    bytes32 public constant MARKETPLACE_ROLE =
        0x0ea61da3a8a09ad801432653699f8c1860b1ae9d2ea4a141fadfd63227717bc8;

    string private _assetBaseURI;

    bytes4 private constant _MARKETPLACE_INTERFACE_ID =
        type(IMarketplace).interfaceId;

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
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) {
        if (!_msgSender().supportsInterface(_MARKETPLACE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        _mint(owner, mainId, 1, 1);
        _approve(owner, _msgSender(), mainId, 1, 1);
        emit AssetCreated(owner, mainId);
    }

    /**
     * @dev See {IAsset-burnAsset}.
     */
    function burnAsset(
        address owner,
        uint256 mainId
    ) external onlyRole(MARKETPLACE_ROLE) {
        if (!_msgSender().supportsInterface(_MARKETPLACE_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        _burn(owner, mainId, 1, 1);
        emit AssetBurnt(owner, mainId);
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
     * @dev See {DLT-_mint}.
     */
    function _mint(
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual override(DLT, DLTEnumerable) {
        super._mint(recipient, mainId, subId, amount);
    }

    /**
     * @dev See {DLT-_burn}.
     */
    function _burn(
        address recipient,
        uint256 mainId,
        uint256 subId,
        uint256 amount
    ) internal virtual override(DLT, DLTEnumerable) {
        super._burn(recipient, mainId, subId, amount);
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
}
