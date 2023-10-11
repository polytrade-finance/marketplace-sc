// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { WrappedInfo } from "contracts/lib/structs.sol";

interface IWrappedAsset {
    /**
     * @dev Emitted when an asset is unwrapped
     * @param owner, address of the asset owner
     * @param contractAddress, addres of asset contract
     * @param tokenId, unique idetifier of asset
     * @param mainId, unique idetifier of wrapped asset
     */
    event ERC721Unwrapped(
        address indexed owner,
        address indexed contractAddress,
        uint256 tokenId,
        uint256 mainId
    );

    /**
     * @dev Emitted when an asset is unwrapped
     * @param owner, address of the asset owner
     * @param contractAddress, addres of asset contract
     * @param tokenId, unique idetifier of asset
     * @param balance, balance of wrapped asset
     * @param mainId, unique idetifier of wrapped asset
     */
    event ERC1155Unwrapped(
        address indexed owner,
        address indexed contractAddress,
        uint256 tokenId,
        uint256 balance,
        uint256 mainId
    );

    /**
     * @dev Emitted when an asset is wrapped to DLT
     * @param owner, address of the asset owner
     * @param contractAddress, addres of asset contract
     * @param tokenId, unique idetifier of asset
     * @param mainId, unique idetifier of wrapped asset
     */
    event ERC721Wrapped(
        address indexed owner,
        address indexed contractAddress,
        uint256 tokenId,
        uint256 mainId
    );

    /**
     * @dev Emitted when an asset is wrapped to DLT
     * @param owner, address of the asset owner
     * @param contractAddress, addres of asset contract
     * @param tokenId, unique idetifier of asset
     * @param balance, balance of wrapped asset
     * @param mainId, unique idetifier of wrapped asset
     */
    event ERC1155Wrapped(
        address indexed owner,
        address indexed contractAddress,
        uint256 tokenId,
        uint256 balance,
        uint256 mainId
    );

    event StatusChanged(address indexed contractAddress, bool status);

    /**
     * @dev Reverted on unsupported interface detection
     */
    error UnsupportedInterface();

    error UnableToReceive();

    function whitelist(address contractAddress, bool status) external;

    /**
     * @dev Wrapps an ERC721 token into DLT
     * @param contractAddress, address of ERC721 contract
     * @param tokenId, unique identifier of ERC721 token
     * @param fractions, number of fractions to fractionalize DLT
     * @dev Needs owner to approve WrappedAsset contract to transfer the ERC721 token
     * @dev Locks the asset in contract
     */
    function wrapERC721(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) external returns (uint256);

    function batchWrapERC721(
        address[] calldata contractAddresses,
        uint256[] calldata tokenIds,
        uint256[] calldata fractions
    ) external returns (uint256[] memory);

    /**
     * @dev Wrapps an ERC1155 token into DLT
     * @param contractAddress, address of ERC1155 contract
     * @param tokenId, unique identifier of ERC1155 token
     * @param fractions, number of fractions to fractionalize DLT
     * @dev Needs owner to approve WrappedAsset contract to transfer the ERC1155 token
     * @dev Locks the asset in contract
     */
    function wrapERC1155(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) external returns (uint256);

    function batchWrapERC1155(
        address[] calldata contractAddresses,
        uint256[] calldata tokenIds,
        uint256[] calldata fractions
    ) external returns (uint256[] memory);

    /**
     * @dev Unwrapps a DLT to ERC721 token
     * @param mainId, unique identifier of wrapped asset
     * @dev Unlocks the underlying ERC721 and transfer it to owner
     */
    function unwrapERC721(uint256 mainId) external;

    /**
     * @dev Unwrapps a DLT to ERC1155 token
     * @param mainId, unique identifier of wrapped asset
     * @dev Unlocks the underlying ERC1155 and transfer it to owner
     */
    function unwrapERC1155(uint256 mainId) external;

    /**
     * @dev Gets the wrapped information
     * @param wrappedMainId, unique identifier of property
     * @return WrappedInfo struct
     */
    function getWrappedInfo(
        uint256 wrappedMainId
    ) external view returns (WrappedInfo memory);
}
