package com.titan.titancorebanking.dto.request;

import jakarta.validation.constraints.DecimalMin;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class AccountRequest {

    private Long userId; // Optional if using path variable, but good to have in body sometimes

    // "SAVINGS", "CHECKING"
    private String accountType;

    // ✅ ADD THIS FIELD (Default can be handled in Service if null)
    private String currency;

    @DecimalMin(value = "0.0", message = "Initial deposit must be positive")
    private BigDecimal initialDeposit;

    private String pin;
}