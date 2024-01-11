// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { IERC1155Receiver } from "@openzeppelin/contracts/interfaces/IERC1155Receiver.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { Context } from "@openzeppelin/contracts/utils/Context.sol";
import { WrappedInfo, IWrappedAsset, IToken } from "contracts/Asset/interface/IWrappedAsset.sol";
import { IBaseAsset } from "contracts/Asset/interface/IBaseAsset.sol";
import { Counters } from "contracts/lib/Counters.sol";

/**
 * @title The wrapped asset contract based on EIP6960
 * @author Polytrade.Finance
 */
contract WrappedAsset is
    Context,
    AccessControl,
    IERC721Receiver,
    IERC1155Receiver,
    IWrappedAsset
{
    using ERC165Checker for address;
    using SafeERC20 for IToken;
    using Counters for Counters.Counter;

    Counters.Counter private _nonce;
    IBaseAsset private _assetCollection;

    // solhint-disable-next-line
    uint256 private CHAIN_ID;

    mapping(uint256 => WrappedInfo) private _wrappedInfo;

    mapping(address => bool) private _isWhitelisted;

    bytes4 private constant _ASSET_INTERFACE_ID = type(IBaseAsset).interfaceId;
    bytes4 private constant _ERC721_INTERFACE_ID = type(IERC721).interfaceId;
    bytes4 private constant _ERC1155_INTERFACE_ID = type(IERC1155).interfaceId;

    modifier isWhitelisted(address contractAddress) {
        if (!_isWhitelisted[contractAddress]) {
            revert NotWhitelisted();
        }
        _;
    }

    /**
     * @dev Constructor for the type contract
     * @param assetCollection_, Address of the asset collection used in the type contract
     */
    constructor(address assetCollection_) {
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
        if (contractAddress == address(0)) {
            revert UnsupportedInterface();
        }
        _isWhitelisted[contractAddress] = status;

        emit StatusChanged(contractAddress, status);
    }

    /**
     * @dev See {IWrappedAsset-wrapERC721}.
     */
    function wrapERC20(
        address contractAddress,
        uint256 balance,
        uint256 fractions
    ) external returns (uint256) {
        return _wrapERC20(contractAddress, balance, fractions);
    }

    /**
     * @dev See {IWrappedAsset-batchWrapERC20}.
     */
    function batchWrapERC20(
        address[] calldata contractAddresses,
        uint256[] calldata balances,
        uint256[] calldata fractions
    ) external returns (uint256[] memory) {
        uint256 length = contractAddresses.length;
        if (balances.length != length || length != fractions.length) {
            revert NoArrayParity();
        }
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _wrapERC20(
                contractAddresses[i],
                balances[i],
                fractions[i]
            );
            unchecked {
                ++i;
            }
        }
        return ids;
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
        if (tokenIds.length != length || length != fractions.length) {
            revert NoArrayParity();
        }
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
        uint256 balance,
        uint256 fractions
    ) external returns (uint256) {
        return _wrapERC1155(contractAddress, tokenId, balance, fractions);
    }

    /**
     * @dev See {IWrappedAsset-batchWrapERC1155}.
     */
    function batchWrapERC1155(
        address[] calldata contractAddresses,
        uint256[] calldata tokenIds,
        uint256[] calldata balances,
        uint256[] calldata fractions
    ) external returns (uint256[] memory) {
        uint256 length = contractAddresses.length;
        if (
            tokenIds.length != length ||
            length != fractions.length ||
            balances.length != length
        ) {
            revert NoArrayParity();
        }
        uint256[] memory ids = new uint256[](length);
        for (uint256 i = 0; i < length; ) {
            ids[i] = _wrapERC1155(
                contractAddresses[i],
                tokenIds[i],
                balances[i],
                fractions[i]
            );

            unchecked {
                ++i;
            }
        }
        return ids;
    }

    /**
     * @dev See {IWrappedAsset-emergencyUnwrapERC20}.
     */
    function emergencyUnwrapERC20(
        uint256 mainId,
        address receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unwrapERC20(receiver, mainId);
    }

    /**
     * @dev See {IWrappedAsset-emergencyUnwrapERC721}.
     */
    function emergencyUnwrapERC721(
        uint256 mainId,
        address receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unwrapERC721(receiver, mainId);
    }

    /**
     * @dev See {IWrappedAsset-emergencyUnwrapERC721}.
     */
    function emergencyUnwrapERC1155(
        uint256 mainId,
        address receiver
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unwrapERC1155(receiver, mainId);
    }

    /**
     * @dev See {IWrappedAsset-unwrapERC20}.
     */
    function unwrapERC20(uint256 mainId) external {
        if (
            _wrappedInfo[mainId].fractions !=
            _assetCollection.subBalanceOf(_msgSender(), mainId, 1)
        ) {
            revert PartialOwnership();
        }
        _unwrapERC20(_msgSender(), mainId);
    }

    /**
     * @dev See {IWrappedAsset-unwrapERC721}.
     */
    function unwrapERC721(uint256 mainId) external {
        if (
            _wrappedInfo[mainId].fractions !=
            _assetCollection.subBalanceOf(_msgSender(), mainId, 1)
        ) {
            revert PartialOwnership();
        }
        _unwrapERC721(_msgSender(), mainId);
    }

    /**
     * @dev See {IWrappedAsset-unwrapERC1155}.
     */
    function unwrapERC1155(uint256 mainId) external {
        if (
            _wrappedInfo[mainId].fractions !=
            _assetCollection.subBalanceOf(_msgSender(), mainId, 1)
        ) {
            revert PartialOwnership();
        }
        _unwrapERC1155(_msgSender(), mainId);
    }

    /**
     * @dev See {IWrappedAsset-getNonce}.
     */
    function getNonce(address account) external view returns (uint256) {
        return _nonce.current(account);
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
    ) external view override returns (bytes4 result) {
        if (operator == address(this)) {
            return IERC1155Receiver.onERC1155Received.selector;
        }
    }

    function onERC721Received(
        address operator,
        address,
        uint256,
        bytes calldata
    ) external view override returns (bytes4 result) {
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

    function _wrapERC20(
        address contractAddress,
        uint256 balance,
        uint256 fractions
    ) private isWhitelisted(contractAddress) returns (uint256 mainId) {
        if (balance == 0) {
            revert InvalidBalance();
        }
        IToken token = IToken(contractAddress);
        uint256 actualBalance = token.balanceOf(_msgSender());
        if (actualBalance < balance) {
            revert NotEnoughBalance();
        }
        mainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    address(this),
                    _msgSender(),
                    _nonce.useNonce(_msgSender())
                )
            )
        );

        if (_assetCollection.totalSubSupply(mainId, 1) != 0) {
            revert AssetAlreadyCreated();
        }
        _wrappedInfo[mainId] = WrappedInfo(
            0,
            fractions,
            balance,
            contractAddress
        );

        token.safeTransferFrom(_msgSender(), address(this), balance);
        _assetCollection.createAsset(_msgSender(), mainId, 1, fractions);

        emit ERC20Wrapped(
            _msgSender(),
            contractAddress,
            balance,
            mainId,
            _nonce.current(_msgSender())
        );
    }

    function _wrapERC721(
        address contractAddress,
        uint256 tokenId,
        uint256 fractions
    ) private isWhitelisted(contractAddress) returns (uint256 mainId) {
        if (!contractAddress.supportsInterface(_ERC721_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        IERC721 token = IERC721(contractAddress);
        if (_msgSender() != token.ownerOf(tokenId)) {
            revert InvalidOwner();
        }
        mainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    address(this),
                    _msgSender(),
                    _nonce.useNonce(_msgSender())
                )
            )
        );
        if (_assetCollection.totalMainSupply(mainId) != 0) {
            revert AssetAlreadyCreated();
        }

        _wrappedInfo[mainId] = WrappedInfo(
            tokenId,
            fractions,
            1,
            contractAddress
        );

        token.safeTransferFrom(_msgSender(), address(this), tokenId, "");
        _assetCollection.createAsset(_msgSender(), mainId, 1, fractions);

        emit ERC721Wrapped(
            _msgSender(),
            contractAddress,
            tokenId,
            mainId,
            _nonce.current(_msgSender())
        );
    }

    function _wrapERC1155(
        address contractAddress,
        uint256 tokenId,
        uint256 balance,
        uint256 fractions
    ) private isWhitelisted(contractAddress) returns (uint256 mainId) {
        if (balance == 0) {
            revert InvalidBalance();
        }
        if (!contractAddress.supportsInterface(_ERC1155_INTERFACE_ID)) {
            revert UnsupportedInterface();
        }
        IERC1155 token = IERC1155(contractAddress);
        uint256 actualBalance = token.balanceOf(_msgSender(), tokenId);
        if (actualBalance < balance) {
            revert NotEnoughBalance();
        }
        mainId = uint256(
            keccak256(
                abi.encodePacked(
                    CHAIN_ID,
                    address(this),
                    _msgSender(),
                    _nonce.useNonce(_msgSender())
                )
            )
        );

        if (_assetCollection.totalSubSupply(mainId, 1) != 0) {
            revert AssetAlreadyCreated();
        }
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
            mainId,
            _nonce.current(_msgSender())
        );
    }

    function _unwrapERC20(address receiver, uint256 mainId) private {
        WrappedInfo memory info = _wrappedInfo[mainId];
        if (info.fractions == 0) {
            revert WrongAssetId();
        }
        IToken token = IToken(info.contractAddress);

        delete _wrappedInfo[mainId];

        _assetCollection.burnAsset(
            receiver,
            mainId,
            1,
            _assetCollection.subBalanceOf(receiver, mainId, 1)
        );
        token.safeTransfer(receiver, info.balance);

        emit ERC20Unwrapped(
            receiver,
            info.contractAddress,
            info.balance,
            mainId
        );
    }

    function _unwrapERC721(address receiver, uint256 mainId) private {
        WrappedInfo memory info = _wrappedInfo[mainId];
        if (info.fractions == 0) {
            revert WrongAssetId();
        }
        IERC721 token = IERC721(info.contractAddress);
        delete _wrappedInfo[mainId];

        _assetCollection.burnAsset(
            receiver,
            mainId,
            1,
            _assetCollection.subBalanceOf(receiver, mainId, 1)
        );
        token.safeTransferFrom(address(this), receiver, info.tokenId, "");

        emit ERC721Unwrapped(
            receiver,
            info.contractAddress,
            info.tokenId,
            mainId
        );
    }

    function _unwrapERC1155(address receiver, uint256 mainId) private {
        WrappedInfo memory info = _wrappedInfo[mainId];
        if (info.fractions == 0) {
            revert WrongAssetId();
        }
        IERC1155 token = IERC1155(info.contractAddress);
        delete _wrappedInfo[mainId];

        _assetCollection.burnAsset(
            receiver,
            mainId,
            1,
            _assetCollection.subBalanceOf(receiver, mainId, 1)
        );
        token.safeTransferFrom(
            address(this),
            receiver,
            info.tokenId,
            info.balance,
            ""
        );

        emit ERC1155Unwrapped(
            receiver,
            info.contractAddress,
            info.tokenId,
            info.balance,
            mainId
        );
    }
}
