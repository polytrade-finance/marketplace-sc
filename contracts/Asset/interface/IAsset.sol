// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/interfaces/IDLT.sol";
import "dual-layer-token/contracts/DLT/interfaces/IDLTEnumerable.sol";
import "dual-layer-token/contracts/DLT/interfaces/IDLTPermit.sol";

interface IAsset is IDLT, IDLTEnumerable, IDLTPermit {
    /**
     * @dev Emitted when `newURI` is set to the assets instead of `oldURI`
     * @param mainId, Asset main id for the URI
     * @param oldBaseURI, Old base URI for the assets
     * @param newBaseURI, New base URI for the assets
     */
    event AssetBaseURISet(uint256 mainId, string oldBaseURI, string newBaseURI);

    /**
     * @dev Emitted when an asset is created
     * @param owner, address of the owner of asset
     * @param mainId, unique identifier of asset type
     * @param subId, unique identifier of asset
     */
    event AssetCreated(address owner, uint256 mainId, uint256 subId);

    /**
     * @dev Emitted when an asset is burnt
     * @param owner, address of the owner of asset
     * @param mainId, unique identifier of asset type
     * @param subId, unique identifier of asset
     */
    event AssetBurnt(address owner, uint256 mainId, uint256 subId);

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    /**
     * @dev Creates an asset with its parameters
     * @param owner, initial owner of asset
     * @param mainId, unique identifier of asset type
     * @param subId, unique identifier of asset
     * @dev Needs marketplace access to create an asset
     */
    function createAsset(address owner, uint256 mainId, uint256 subId) external;

    /**
     * @dev Burns an asset with its parameters
     * @param owner, initial owner of asset
     * @param mainId, unique identifier of asset type
     * @param subId, unique identifier of asset
     * @dev Needs marketplace access to create an asset
     */
    function burnAsset(address owner, uint256 mainId, uint256 subId) external;

    /**
     * @dev Set a new baseURI for assets
     * @dev Needs admin access to schange base URI
     * @param newBaseURI, string value of new URI
     */
    function setBaseURI(uint256 mainId, string calldata newBaseURI) external;

    /**
     * @dev concatenate asset id (mainId) to baseURI
     * @param mainId, unique identifier of asset type
     * @param subId, unique identifier of asset
     * @return string value of asset URI
     */
    function tokenURI(
        uint256 mainId,
        uint256 subId
    ) external view returns (string memory);
}
