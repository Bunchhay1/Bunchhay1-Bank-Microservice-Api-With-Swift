package com.titan.adapter.dto.xml;

import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import jakarta.xml.bind.annotation.XmlRootElement;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@JacksonXmlRootElement(localName = "TXN_REQUEST")
@XmlRootElement(name = "TXN_REQUEST")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransactionRequest {
    
    private String transactionId;
    private String transactionType;
    private String accountNumber;
    private String amount;
    private String currency;
    private String timestamp;
}
