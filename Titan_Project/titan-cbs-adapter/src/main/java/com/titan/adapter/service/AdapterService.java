package com.titan.adapter.service;

import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.titan.adapter.dto.json.TransferRequest;
import com.titan.adapter.dto.json.TransferResponse;
import com.titan.adapter.dto.xml.TransactionRequest;
import com.titan.adapter.dto.xml.TransactionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.RoundingMode;
import java.time.Instant;
import java.time.format.DateTimeFormatter;

@Service
public class AdapterService {
    
    private static final Logger logger = LoggerFactory.getLogger(AdapterService.class);
    
    private final LegacySystemService legacySystemService;
    private final XmlMapper xmlMapper;

    public AdapterService(LegacySystemService legacySystemService, XmlMapper xmlMapper) {
        this.legacySystemService = legacySystemService;
        this.xmlMapper = xmlMapper;
    }

    /**
     * TRANSFORMATION LAYER: Convert clean JSON to ugly XML
     */
    private TransactionRequest transformJsonToXml(TransferRequest jsonRequest) {
        logger.info("==== ANTI-CORRUPTION LAYER: TRANSFORMING JSON TO XML ====");
        logger.info("Clean JSON Request: {}", jsonRequest);
        
        TransactionRequest xmlRequest = new TransactionRequest();
        xmlRequest.setTransactionId(jsonRequest.getTransactionId());
        xmlRequest.setTransactionType(jsonRequest.getTransactionType());
        
        // Map "fromAccount" to legacy "accountNumber" field
        xmlRequest.setAccountNumber(jsonRequest.getFromAccount());
        
        // Convert BigDecimal amount to String for legacy system
        xmlRequest.setAmount(jsonRequest.getAmount().setScale(2, RoundingMode.HALF_UP).toString());
        xmlRequest.setCurrency(jsonRequest.getCurrency());
        
        // Format timestamp for legacy system
        xmlRequest.setTimestamp(jsonRequest.getTimestamp());
        
        logger.info("Ugly XML Request: {}", xmlRequest);
        logger.info("======================================================\n");
        
        return xmlRequest;
    }

    /**
     * TRANSFORMATION LAYER: Convert ugly XML to clean JSON
     */
    private TransferResponse transformXmlToJson(TransactionResponse xmlResponse) {
        logger.info("==== ANTI-CORRUPTION LAYER: TRANSFORMING XML TO JSON ====");
        logger.info("Ugly XML Response: {}", xmlResponse);
        
        TransferResponse jsonResponse = TransferResponse.builder()
                .status(xmlResponse.getResponseCode().equals("000") ? "SUCCESS" : "FAILED")
                .message(xmlResponse.getResponseMessage())
                .transactionId(xmlResponse.getTransactionId())
                .authorizationCode(xmlResponse.getAuthorizationCode())
                .processedAt(DateTimeFormatter.ISO_INSTANT.format(
                        Instant.ofEpochMilli(Long.parseLong(xmlResponse.getProcessedTimestamp()))))
                .gateway("Titan-ACL-Adapter-v1")
                .build();
        
        logger.info("Clean JSON Response: {}", jsonResponse);
        logger.info("======================================================\n");
        
        return jsonResponse;
    }

    /**
     * MAIN METHOD: Accept JSON, transform to XML, call legacy, transform back to JSON
     */
    public TransferResponse processTransfer(TransferRequest jsonRequest) {
        logger.info("=== TITAN CBS ADAPTER: INITIATING TRANSFER ===");
        logger.info("Transaction ID: {}", jsonRequest.getTransactionId());
        
        // Step 1: Transform JSON to XML
        TransactionRequest xmlRequest = transformJsonToXml(jsonRequest);
        
        // Step 2: Call legacy system with XML
        TransactionResponse xmlResponse = legacySystemService.sendTransactionToLegacy(xmlRequest);
        
        // Step 3: Transform XML back to JSON
        TransferResponse jsonResponse = transformXmlToJson(xmlResponse);
        
        logger.info("=== TITAN CBS ADAPTER: TRANSFER COMPLETE ===\n");
        return jsonResponse;
    }
}
