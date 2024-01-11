// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title The test NFT token
 * @author Polytrade.Finance
 */
contract ERC721Token is ERC721 {

    error wrongOwner();

    constructor(
        string memory name_,
        string memory symbol_
    ) ERC721(name_, symbol_) {
        _mint(msg.sender, 1);
    }

    function mint(uint256 tokenId) external {
        _mint(msg.sender, tokenId);
    }

    function burn(uint256 tokenId) external {
        if(msg.sender != ownerOf(tokenId)){
            revert wrongOwner();
        }
        _burn(tokenId);
    }
}
