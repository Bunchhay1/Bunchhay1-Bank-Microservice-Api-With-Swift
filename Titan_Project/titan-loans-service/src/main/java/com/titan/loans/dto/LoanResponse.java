package com.titan.loans.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoanResponse {

    private Long id;
    private Long accountId;
    private String accountNumber;
    private String username;

    /** Principal loan amount */
    private BigDecimal amount;

    /** Monthly interest rate (0.05 = 5% per month) */
    private BigDecimal interestRate;

    /** Loan term in months */
    private Integer termMonths;

    /** Fixed monthly repayment amount */
    private BigDecimal monthlyPayment;

    /** One-time 4% processing fee charged on approval */
    private BigDecimal processingFee;

    private String status;
    private String note;
    private LocalDateTime appliedAt;
    private LocalDateTime approvedAt;
    private LocalDateTime rejectedAt;
}
