package com.titan.adapter.dto.json;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransferResponse {
    
    private String status;
    private String message;
    private String transactionId;
    private String authorizationCode;
    private String processedAt;
    private String gateway;
}
