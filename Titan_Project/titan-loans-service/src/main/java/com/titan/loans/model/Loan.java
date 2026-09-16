package com.titan.loans.model;

import com.titan.loans.enums.LoanStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * Loan entity — owned by titan-loans-service.
 *
 * Relates to titan-core-banking accounts by accountId (Long) and accountNumber (String).
 * We do NOT embed a JPA relationship to Account — the two services have separate DBs.
 * Cross-service account lookups go through the Core Banking REST API.
 *
 * ── Business rules ───────────────────────────────────────────────────────────
 * - Max loan = 10% of account balance
 * - Processing fee = 4% of loan amount (charged to account on approval)
 * - Monthly interest rate = 5% per month (fixed)
 */
@Entity
@Table(name = "loans")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Loan {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    /** ID of the account in titan-core-banking */
    @Column(name = "account_id", nullable = false)
    private Long accountId;

    /** Account number for display / cross-service lookup */
    @Column(name = "account_number", nullable = false)
    private String accountNumber;

    /** Username of the applicant (from JWT) */
    @Column(name = "username", nullable = false)
    private String username;

    /** Principal loan amount */
    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal amount;

    /**
     * Fixed monthly interest rate = 0.05 (5% per month).
     * Stored for transparency; always set to 0.05 by LoanService.
     */
    @Column(name = "interest_rate", nullable = false, precision = 5, scale = 4)
    private BigDecimal interestRate;

    /** Loan term in months */
    @Column(name = "term_months", nullable = false)
    private Integer termMonths;

    /**
     * One-time processing fee = 4% of amount.
     * Charged to the account on approval via titan-core-banking.
     */
    @Column(name = "processing_fee", nullable = false, precision = 19, scale = 2)
    private BigDecimal processingFee;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private LoanStatus status;

    /** Optional note submitted by the applicant */
    private String note;

    @Builder.Default
    @Column(name = "applied_at", nullable = false)
    private LocalDateTime appliedAt = LocalDateTime.now();

    @Column(name = "approved_at")
    private LocalDateTime approvedAt;

    @Column(name = "rejected_at")
    private LocalDateTime rejectedAt;
}
