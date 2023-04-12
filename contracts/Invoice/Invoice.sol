// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "dual-layer-token/contracts/DLT/DLT.sol";
import "./interface/IInvoice.sol";

contract Invoice is IInvoice, DLT {
    constructor(string memory name, string memory symbol) DLT(name, symbol) {}
}
