// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title The token used to pay for getting AssetNFTs
 * @author Polytrade.Finance
 * @dev IERC20 used for test purposes
 */
contract Token is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        address receiver_,
        uint totalSupply_
    ) ERC20(name_, symbol_) {
        _mint(receiver_, totalSupply_ * 1 ether);
    }
}
