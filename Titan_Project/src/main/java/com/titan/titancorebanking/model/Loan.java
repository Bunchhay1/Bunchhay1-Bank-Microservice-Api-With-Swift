package com.titan.titancorebanking.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties; // ✅ IMPORT
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Getter @Setter @Builder @NoArgsConstructor @AllArgsConstructor
@Entity @Table(name = "loans")
public class Loan {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    // ✅ FIX: ការពារ Error 500 ពេល Return JSON (Ignore Proxy Garbage)
    @JsonIgnoreProperties({"hibernateLazyInitializer", "handler", "user", "transactions"})
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "account_id", nullable = false)
    private Account account;

    private BigDecimal amount;
    private BigDecimal interestRate;
    private Integer termMonths;
    private String status; // PENDING, APPROVED, REJECTED, PAID

    @Builder.Default
    private LocalDateTime appliedAt = LocalDateTime.now();
}