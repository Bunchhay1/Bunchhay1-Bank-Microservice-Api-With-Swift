package com.titan.titancorebanking.event;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@AllArgsConstructor
@NoArgsConstructor
public class TransactionEvent {
    private String username;
    private BigDecimal amount;
    private String type; // TRANSFER, DEPOSIT, WITHDRAWAL
    private String message;
}