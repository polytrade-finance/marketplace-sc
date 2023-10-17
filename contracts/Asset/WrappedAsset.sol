// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { WrappedInfo, IWrappedAsset } from "contracts/Asset/interface/IWrappedAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";

/**
 * @title The wrapped asset contract based on EIP6960
 * @author Polytrade.Finance
 */
contract WrappedAsset is
    Initializable,
    Context,
    AccessControl,
    IERC721Receiver,
    IERC1155Receiver,
    IWrappedAsset
{
    using ERC165Checker for address;

    IBaseAsset private _assetCollection;

    // solhint-disable-next-line
    uint256 private CHAIN_ID;

    mapping(uint256 => WrappedInfo) private _wrappedInfo;

    mapping(address => bool) private _isWhitelisted;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;
    bytes4 private constant _ERC721_INTERFACE_ID = type(IERC721).interfaceId;
    bytes4 private constant _ERC1155_INTERFACE_ID = type(IERC1155).interfaceId;

    modifier isWhitelisted(address contractAddress) {
        require(_isWhitelisted[contractAddress], "contract not whitelisted");
        _;
    }

    /**
     * @dev Initializer for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     */
    function initialize(address assetCollection_) external initializer {
        if (!assetCollection_.supportsInterface(_ASSET_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }

        _assetCollection = IBaseAsset(assetCollection_);
        CHAIN_ID = block.chainid;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function whitelist(
        address contractAddress,
        bool status
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            !contractAddress.supportsInterface(_ERC721_INTERFACE_ID) &&
            !contractAddress.supportsInterface(_ERC1155_INTERFACE_ID)
        ) {
            revert UnsupportedInterface();
        }
        _isWhitelisted[contractAddress] = status;

        emit StatusChanged(contractAddress, status);
    }

    /**
     * @dev See {IWrappedAsset-wrapERC721}.
     */
    function wrapERC721(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) external returns (uint256) {
        return _wrapERC721(contractAddress, tokenId, fractions);
    }

    /**
     * @dev See {IWrappedAsset-batchWrapERC721}.
     */
    function batchWrapERC721(
        address[] calldata contractAddresses,
        uint256[] calldata tokenIds,
        uint256[] calldata fractions
    ) external returns (uint256[] memory) {
        uint256 length = contractAddresses.length;
        require(
            tokenIds.length == length && length == fractions.length,
            "No array parity"
        );
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _wrapERC721(
                contractAddresses[i],
                tokenIds[i],
                fractions[i]
            );
            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
     * @dev See {IWrappedAsset-wrapERC1155}.
     */
    function wrapERC1155(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) external returns (uint256) {
        return _wrapERC1155(contractAddress, tokenId, fractions);
    }

    /**
     * @dev See {IWrappedAsset-batchWrapERC1155}.
     */
    function batchWrapERC1155(
        address[] calldata contractAddresses,
        uint256[] calldata tokenIds,
        uint256[] calldata fractions
    ) external returns (uint256[] memory) {
        uint256 length = contractAddresses.length;
        require(
            tokenIds.length == length && length == fractions.length,
            "No array parity"
        );
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _wrapERC1155(
                contractAddresses[i],
                tokenIds[i],
                fractions[i]
            );

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
     * @dev See {IWrappedAsset-unwrapERC721}.
     */
    function unwrapERC721(uint256 mainId) external {
        _unwrapERC721(mainId);
    }

    /**
     * @dev See {IWrappedAsset-unwrapERC1155}.
     */
    function unwrapERC1155(uint256 mainId) external {
        _unwrapERC1155(mainId);
    }

    function getWrappedInfo(
        uint256 wrappedMainId
    ) external view returns (WrappedInfo memory) {
        return _wrappedInfo[wrappedMainId];
    }

    function onERC1155Received(
        address operator,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        if (operator == address(this)) {
            return IERC1155Receiver.onERC1155Received.selector;
        }
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4) {
        if (operator == address(this)) {
            return IERC721Receiver.onERC721Received.selector;
        }
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        revert UnableToReceive();
    }

    function _wrapERC721(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) private isWhitelisted(contractAddress) returns (uint256 mainId) {
        IERC721 token = IERC721(contractAddress);
        require(
            _msgSender() == token.ownerOf(tokenId),
            "You are not the owner"
        );

        mainId = uint256(
            keccak256(abi.encodePacked(CHAIN_ID, contractAddress, tokenId))
        );

        require(
            _assetCollection.totalSubSupply(mainId, 1) == 0,
            "Asset already created"
        );

        _wrappedInfo[mainId] = WrappedInfo(
            tokenId,
            fractions,
            1,
            contractAddress
        );

        token.safeTransferFrom(_msgSender(), address(this), tokenId, "");
        _assetCollection.createAsset(_msgSender(), mainId, 1, fractions);

        emit ERC721Wrapped(_msgSender(), contractAddress, tokenId, mainId);
    }

    function _wrapERC1155(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) private isWhitelisted(contractAddress) returns (uint256 mainId) {
        IERC1155 token = IERC1155(contractAddress);
        uint256 balance = token.balanceOf(_msgSender(), tokenId);
        require(balance != 0, "Not enough balance");

        mainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    _msgSender(),
                    contractAddress,
                    tokenId
                )
            )
        );

        require(
            _assetCollection.totalSubSupply(mainId, 1) == 0,
            "Asset already created"
        );

        _wrappedInfo[mainId] = WrappedInfo(
            tokenId,
            fractions,
            balance,
            contractAddress
        );

        token.safeTransferFrom(
            _msgSender(),
            address(this),
            tokenId,
            balance,
            ""
        );
        _assetCollection.createAsset(_msgSender(), mainId, 1, fractions);

        emit ERC1155Wrapped(
            _msgSender(),
            contractAddress,
            tokenId,
            balance,
            mainId
        );
    }

    function _unwrapERC721(uint256 mainId) private {
        WrappedInfo memory info = _wrappedInfo[mainId];
        _preCheck(mainId, info.fractions);

        IERC721 token = IERC721(info.contractAddress);
        delete _wrappedInfo[mainId];

        _assetCollection.burnAsset(_msgSender(), mainId, 1, info.fractions);
        token.safeTransferFrom(address(this), _msgSender(), info.tokenId, "");

        emit ERC721Unwrapped(
            _msgSender(),
            info.contractAddress,
            info.tokenId,
            mainId
        );
    }

    function _unwrapERC1155(uint256 mainId) private {
        WrappedInfo memory info = _wrappedInfo[mainId];
        _preCheck(mainId, info.fractions);

        IERC1155 token = IERC1155(info.contractAddress);
        delete _wrappedInfo[mainId];

        _assetCollection.burnAsset(_msgSender(), mainId, 1, info.fractions);
        token.safeTransferFrom(
            address(this),
            _msgSender(),
            info.tokenId,
            info.balance,
            ""
        );

        emit ERC1155Unwrapped(
            _msgSender(),
            info.contractAddress,
            info.tokenId,
            info.balance,
            mainId
        );
    }

    function _preCheck(uint256 mainId, uint256 fractions) private view {
        require(fractions != 0, "Wrong asset id");
        require(
            fractions == _assetCollection.subBalanceOf(_msgSender(), mainId, 1),
            "Partial ownership"
        );
    }
}
