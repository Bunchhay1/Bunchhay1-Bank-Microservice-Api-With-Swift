package com.titan.legacy.dto;

import com.fasterxml.jackson.dataformat.xml.annotation.JacksonXmlRootElement;
import jakarta.xml.bind.annotation.XmlRootElement;

@JacksonXmlRootElement(localName = "TXN_RESPONSE")
@XmlRootElement(name = "TXN_RESPONSE")
public class TransactionResponse {
    
    private String responseCode;
    private String responseMessage;
    private String authorizationCode;
    private String transactionId;
    private String transactionStatus;
    private String processedTimestamp;

    public TransactionResponse() {}

    public static TransactionResponse success(String transactionId) {
        TransactionResponse response = new TransactionResponse();
        response.setResponseCode("000");
        response.setResponseMessage("SUCCESS");
        response.setAuthorizationCode("LEGACY-AUTH-" + System.currentTimeMillis());
        response.setTransactionId(transactionId);
        response.setTransactionStatus("COMPLETED");
        response.setProcessedTimestamp(String.valueOf(System.currentTimeMillis()));
        return response;
    }

    public String getResponseCode() {
        return responseCode;
    }

    public void setResponseCode(String responseCode) {
        this.responseCode = responseCode;
    }

    public String getResponseMessage() {
        return responseMessage;
    }

    public void setResponseMessage(String responseMessage) {
        this.responseMessage = responseMessage;
    }

    public String getAuthorizationCode() {
        return authorizationCode;
    }

    public void setAuthorizationCode(String authorizationCode) {
        this.authorizationCode = authorizationCode;
    }

    public String getTransactionId() {
        return transactionId;
    }

    public void setTransactionId(String transactionId) {
        this.transactionId = transactionId;
    }

    public String getTransactionStatus() {
        return transactionStatus;
    }

    public void setTransactionStatus(String transactionStatus) {
        this.transactionStatus = transactionStatus;
    }

    public String getProcessedTimestamp() {
        return processedTimestamp;
    }

    public void setProcessedTimestamp(String processedTimestamp) {
        this.processedTimestamp = processedTimestamp;
    }

    @Override
    public String toString() {
        return "TransactionResponse{" +
                "responseCode='" + responseCode + '\'' +
                ", responseMessage='" + responseMessage + '\'' +
                ", authorizationCode='" + authorizationCode + '\'' +
                ", transactionId='" + transactionId + '\'' +
                ", transactionStatus='" + transactionStatus + '\'' +
                ", processedTimestamp='" + processedTimestamp + '\'' +
                '}';
    }
}
