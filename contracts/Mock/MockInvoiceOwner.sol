// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { ListedInfo, IToken, IMarketplace } from "contracts/Marketplace/interface/IMarketplace.sol";

contract MockInvoiceOwner {
    IMarketplace private immutable _marketplace;

    constructor(address marketplace_) {
        _marketplace = IMarketplace(marketplace_);
    }

    function list(uint256 mainId) external {
        ListedInfo memory _listedInfo = ListedInfo(
            1,
            1000,
            1,
            IToken(msg.sender)
        );

        _marketplace.list(mainId, 0, _listedInfo);
    }

    function onSubIdCreation(
        address owner,
        uint256 mainId,
        uint256 fractions
    ) external {
        _marketplace.buy(mainId, 0, fractions, owner);
    }

    function getTreasuryWallet() external view returns (address) {
        return msg.sender;
    }
}
