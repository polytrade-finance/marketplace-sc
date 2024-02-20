// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title The test NFT token
 * @author Polytrade.Finance
 */
contract MockERC721 is ERC721, Ownable {
    using Strings for uint256;

    string public uri;

    error wrongOwner();

    constructor(
        string memory name_,
        string memory symbol_,
        string memory uri_
    ) ERC721(name_, symbol_) {
        _mint(msg.sender, 1);
        uri = uri_;
    }

    function changeURI(string memory newURI) external onlyOwner {
        uri = newURI;
    }

    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId);
    }

    function burn(uint256 tokenId) external {
        if (msg.sender != ownerOf(tokenId)) {
            revert wrongOwner();
        }
        _burn(tokenId);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return uri;
    }
}
