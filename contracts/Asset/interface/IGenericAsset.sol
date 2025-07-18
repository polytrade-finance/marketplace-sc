// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import { GenericErrors } from "contracts/lib/errors.sol";

interface IGenericAsset is GenericErrors {
    /**
     * @dev Gets the calculated APR
     * @param owner, the owner of the invoice
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     */
    function getApr(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256);

    /**
     * @dev Gets the asset price
     * @param owner, the owner of the invoice
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     */
    function getPrice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId
    ) external view returns (uint256);

    /**
     * @dev Gets the asset price
     * @param owner, the owner of the invoice
     * @param invoiceMainId, unique identifier of invoice
     * @param invoiceSubId, unique identifier of invoice
     * @param fractions, number of fractions
     */
    function getPartialPrice(
        address owner,
        uint256 invoiceMainId,
        uint256 invoiceSubId,
        uint256 fractions
    ) external view returns (uint256);
}
