package com.titan.loans.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoanApprovalResponse {

    private String message;
    private Long loanId;

    /** Fixed monthly repayment at 5% per month */
    private BigDecimal monthlyPayment;

    /** One-time processing fee (4% of principal) already deducted */
    private BigDecimal processingFee;

    private int totalRepayments;
}
