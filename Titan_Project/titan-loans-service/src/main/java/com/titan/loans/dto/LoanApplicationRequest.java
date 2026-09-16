package com.titan.loans.dto;

import jakarta.validation.constraints.*;
import lombok.Data;

import java.math.BigDecimal;

/**
 * POST /api/v1/loans/apply
 *
 * Eligibility rules (enforced in LoanService):
 *  - Max loan = 10% of account balance
 *      balance  $1,000  → max $100
 *      balance $10,000  → max $1,000
 *  - Processing fee = 4% of loan amount (deducted from account on approval)
 *  - Monthly interest = 5% per month (fixed, set automatically)
 */
@Data
public class LoanApplicationRequest {

    @NotNull(message = "accountId is required")
    private Long accountId;

    @NotBlank(message = "accountNumber is required")
    private String accountNumber;

    /**
     * Requested loan amount.
     * Must be between $10 and $100,000.
     * Final eligibility limit = 10% of actual account balance (checked at runtime).
     */
    @NotNull(message = "amount is required")
    @DecimalMin(value = "10.00", message = "Minimum loan amount is $10.00")
    @DecimalMax(value = "100000.00", message = "Maximum loan amount is $100,000.00")
    private BigDecimal amount;

    /**
     * Loan term in months (1 – 360). Defaults to 12.
     * Monthly payment is calculated at 5% per month.
     */
    @Min(value = 1,   message = "Minimum term is 1 month")
    @Max(value = 360, message = "Maximum term is 360 months (30 years)")
    private Integer termMonths = 12;

    /** Optional note from the applicant. */
    private String note;
}
