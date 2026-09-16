package com.titan.adapter.service;

import com.fasterxml.jackson.dataformat.xml.XmlMapper;
import com.titan.adapter.dto.xml.TransactionRequest;
import com.titan.adapter.dto.xml.TransactionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.time.Instant;

@Service
public class LegacySystemService {
    
    private static final Logger logger = LoggerFactory.getLogger(LegacySystemService.class);
    
    @Value("${legacy.service.url}")
    private String legacyServiceUrl;
    
    private final RestTemplate restTemplate;
    private final XmlMapper xmlMapper;

    public LegacySystemService(XmlMapper xmlMapper) {
        this.xmlMapper = xmlMapper;
        this.restTemplate = new RestTemplate();
    }

    /**
     * Sends transaction request to legacy system and returns XML response
     */
    public TransactionResponse sendTransactionToLegacy(TransactionRequest request) {
        try {
            logger.info("==== ANTI-CORRUPTION LAYER: CALLING LEGACY SYSTEM ====");
            logger.info("Legacy URL: {}/mainframe/v1/txn", legacyServiceUrl);
            logger.info("Transaction ID: {}", request.getTransactionId());
            
            // Convert TransactionRequest to XML
            String xmlRequest = xmlMapper.writeValueAsString(request);
            logger.info("Outgoing XML: {}", xmlRequest);
            
            // Set headers for XML content
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_XML);
            headers.setAccept(java.util.Collections.singletonList(MediaType.APPLICATION_XML));
            
            // Create HTTP entity with XML body
            HttpEntity<String> entity = new HttpEntity<>(xmlRequest, headers);
            
            // Call legacy system
            String legacyUrl = legacyServiceUrl + "/mainframe/v1/txn";
            ResponseEntity<String> response = restTemplate.exchange(
                    legacyUrl,
                    HttpMethod.POST,
                    entity,
                    String.class
            );
            
            // Parse XML response
            String xmlResponse = response.getBody();
            logger.info("Incoming XML: {}", xmlResponse);
            
            TransactionResponse transactionResponse = xmlMapper.readValue(
                    xmlResponse,
                    TransactionResponse.class
            );
            
            logger.info("Legacy Response Code: {}", transactionResponse.getResponseCode());
            logger.info("Authorization Code: {}", transactionResponse.getAuthorizationCode());
            logger.info("====================================================\n");
            
            return transactionResponse;
            
        } catch (Exception e) {
            logger.error("Failed to communicate with legacy system", e);
            throw new RuntimeException("Legacy system communication failed: " + e.getMessage(), e);
        }
    }
}
