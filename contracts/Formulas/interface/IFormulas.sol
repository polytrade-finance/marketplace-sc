// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/**
 * @title The main interface to calculate all formulas related to Invoice
 * @author Polytrade.Finance
 * @dev Collection of all functions related to Invoice formulas
 */
interface IFormulas {
    /**
     * @dev Calculate the advanced amount: (amount * Advance Ratio)
     * @return uint Advanced Amount
     * @param _amount, uint input from user
     * @param _advanceFeePercentage, uint input from user
     */
    function advanceAmountCalculation(
        uint _amount,
        uint _advanceFeePercentage
    ) external pure returns (uint);

    /**
     * @dev Calculate the factoring amount: (Invoice Amount * Factoring Fee)
     * @return uint Factoring Amount
     * @param invoiceAmount, uint input from user
     * @param factoringFeePercentage, uint input from user
     */
    function factoringFeeAmountCalculation(
        uint invoiceAmount,
        uint factoringFeePercentage
    ) external pure returns (uint);

    /**
     * @dev Calculate the number of late days: (Payment Receipt Date - Due Date - Grace Period)
     * @notice Number of late days will never be less than ‘0’
     * @return uint Number of Late Days
     * @param paymentReceiptDate, uint input from user or can be set automatically
     * @param dueDate, uint input from user
     * @param gracePeriod, uint input from user
     */
    function lateDaysCalculation(
        uint paymentReceiptDate,
        uint dueDate,
        uint gracePeriod
    ) external pure returns (uint);

    /**
     * @dev Calculate the late amount: (Late Fee (%) * (Advanced Amount / 365) * Late Days)
     * @return uint Late Amount
     * @param lateFeePercentage, uint input from user
     * @param lateDays, uint calculated based on user inputs
     * @param advancedAmount, uint calculated based on user inputs
     */
    function lateFeeAmountCalculation(
        uint lateFeePercentage,
        uint lateDays,
        uint advancedAmount
    ) external pure returns (uint);

    /**
     * @dev Calculate the invoice tenure: (Due Date - Invoice Date)
     * @return uint Invoice Tenure
     * @param dueDate, uint input from user
     * @param invoiceDate, uint input from user
     */
    function invoiceTenureCalculation(
        uint dueDate,
        uint invoiceDate
    ) external pure returns (uint);

    /**
     * @dev Calculate the finance tenure: (Payment Receipt Date - Date of Funds Advanced)
     * @return uint Finance Tenure
     * @param paymentReceiptDate, uint input from user
     * @param fundsAdvancedDate, uint input from user
     */
    function financeTenureCalculation(
        uint paymentReceiptDate,
        uint fundsAdvancedDate
    ) external pure returns (uint);

    /**
     * @dev Calculate the discount amount:
     * (Discount Fee (%) * (Advanced Amount / 365) * (Finance Tenure - Late Days))
     * @return uint Amount of the Discount
     * @param discountFeePercentage, uint input from user
     * @param financeTenure, uint input from user
     * @param lateDays, uint calculated based on user inputs
     * @param advancedAmount, uint calculated based on user inputs
     */
    function discountAmountCalculation(
        uint discountFeePercentage,
        uint financeTenure,
        uint lateDays,
        uint advancedAmount
    ) external pure returns (uint);

    /**
     * @dev Calculate the total fees amount:
     * (Factoring Amount + Discount Amount + Additional Fee + Bank Charges Fee)
     * @return uint Total Amount
     * @param factoringFeeAmount, uint input from user
     * @param discountFeeAmount, uint input from user
     * @param additionalFeeAmount, uint input from user
     * @param bankChargesFeeAmount, uint input from user
     */
    function totalFeesAmountCalculation(
        uint factoringFeeAmount,
        uint discountFeeAmount,
        uint additionalFeeAmount,
        uint bankChargesFeeAmount
    ) external pure returns (uint);

    /**
     * @dev Calculate the total amount received:
     * (Amount Received from Buyer + Amount Received from Supplier)
     * @return uint Total Received Amount
     * @param buyerAmountReceived, uint input from user
     * @param supplierAmountReceived, uint input from user
     */
    function totalAmountReceivedCalculation(
        uint buyerAmountReceived,
        uint supplierAmountReceived
    ) external pure returns (uint);

    /**
     * @dev Calculate the net amount payable to the client:
     * (Total amount received – Advanced amount – Total Fees)
     * @return uint Net Amount Payable to the Client
     * @param totalAmountReceived, uint calculated based on user inputs
     * @param advancedAmount, uint calculated based on user inputs
     * @param totalFees, uint calculated based on user inputs
     */
    function netAmountPayableToClientCalculation(
        uint totalAmountReceived,
        uint advancedAmount,
        uint totalFees
    ) external pure returns (int);

    /**
     * @dev Calculate the reserve amount: (Invoice Amount - Advanced Amount)
     * @return uint Reserve Amount
     * @param invoiceAmount, uint input from user
     * @param advancedAmount, uint calculated based on user inputs
     */
    function reserveAmountCalculation(
        uint invoiceAmount,
        uint advancedAmount
    ) external pure returns (uint);
}
