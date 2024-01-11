// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface GenericErrors {
    error InvalidAddress();

    error NoArrayParity();

    error InvalidFraction();

    error InvalidPrice();

    error NotEnoughBalance();

    error DueDateNotPassed();

    error InvalidDueDate();
}
