package com.titan.loans.model;

import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * One row per amortization instalment or manual repayment.
 * Instalment rows are generated on loan approval; status starts as PENDING.
 * When paid, paidDate is set and status → PAID.
 */
@Entity
@Table(name = "loan_repayments")
@Getter
@Setter
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LoanRepayment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "loan_id", nullable = false)
    private Loan loan;

    /** Scheduled due date for this instalment */
    @Column(name = "due_date", nullable = false)
    private LocalDateTime dueDate;

    /** Instalment / repayment amount */
    @Column(nullable = false, precision = 19, scale = 2)
    private BigDecimal amount;

    /** PENDING → PAID */
    @Column(nullable = false)
    @Builder.Default
    private String status = "PENDING";

    /** Timestamp when the payment was actually made (null until paid) */
    @Column(name = "paid_date")
    private LocalDateTime paidDate;
}
