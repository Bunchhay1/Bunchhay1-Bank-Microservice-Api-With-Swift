package com.titan.adapter.dto.json;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransferRequest {
    
    private String transactionId;
    private String transactionType;
    private String fromAccount;
    private String toAccount;
    private BigDecimal amount;
    private String currency;
    private String timestamp;
    private String reference;
}
