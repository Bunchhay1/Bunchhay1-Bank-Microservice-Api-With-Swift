package com.titan.titancorebanking.dto.response;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class TransactionResponse {
    private Long id;
    private String type;
    private BigDecimal amount;
    private String note;

    // ✅ ADD THIS MISSING FIELD
    private String status;

    private LocalDateTime timestamp;
    private String fromAccountNumber;
    private String toAccountNumber;
    private String fromOwnerName;
    private String toOwnerName;
}