// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface GenericErrors {
    error InvalidAddress();

    error NoArrayParity();

    error InvalidFraction();

    error InvalidPrice();

    error InvalidApr();

    error InvalidTenure();

    error InvalidDueAmount();

    error NotEnoughBalance();

    error DueDateNotPassed();

    error InvalidInvoiceDate();

    error InvalidDueDate();

    error BatchLimitExceeded();

    error InvalidAccess();
}
