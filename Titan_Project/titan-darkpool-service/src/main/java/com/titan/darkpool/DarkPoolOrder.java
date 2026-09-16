package com.titan.darkpool;

import lombok.Data;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Data
public class DarkPoolOrder {
    private String orderId = UUID.randomUUID().toString();
    private String clientId;
    private String fromCurrency;
    private String toCurrency;
    private BigDecimal amount;
    private OrderSide side;
    private Instant timestamp = Instant.now();
    
    public enum OrderSide { BUY, SELL }
    
    public String getPair() {
        return fromCurrency + "/" + toCurrency;
    }
    
    public String getReversePair() {
        return toCurrency + "/" + fromCurrency;
    }
}
