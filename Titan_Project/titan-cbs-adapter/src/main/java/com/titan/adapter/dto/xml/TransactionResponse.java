package com.titan.adapter.dto.xml;

import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import jakarta.xml.bind.annotation.XmlRootElement;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@JacksonXmlRootElement(localName = "TXN_RESPONSE")
@XmlRootElement(name = "TXN_RESPONSE")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransactionResponse {
    
    private String responseCode;
    private String responseMessage;
    private String authorizationCode;
    private String transactionId;
    private String transactionStatus;
    private String processedTimestamp;
}
