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
public class RepaymentResponse {

    private Long id;
    private Long loanId;
    private LocalDateTime dueDate;
    private BigDecimal amount;
    private String status;
    private LocalDateTime paidDate;
}
