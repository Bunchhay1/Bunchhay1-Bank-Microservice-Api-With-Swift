package com.titan.legacy.controller;

import com.titan.legacy.dto.TransactionRequest;
import com.titan.legacy.dto.TransactionResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/mainframe/v1")
public class MainframeController {
    
    private static final Logger logger = LoggerFactory.getLogger(MainframeController.class);

    @PostMapping(value = "/txn", consumes = MediaType.APPLICATION_XML_VALUE, produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<TransactionResponse> processTransaction(@RequestBody TransactionRequest request) {
        logger.info("=== LEGACY MAINFRAME SIMULATOR ===");
        logger.info("Processing transaction ID: {}", request.getTransactionId());
        logger.info("Transaction Type: {}", request.getTransactionType());
        logger.info("Account Number: {}", request.getAccountNumber());
        logger.info("Amount: {} {}", request.getAmount(), request.getCurrency());
        
        // Simulate slow mainframe processing (20-year-old system)
        // LOAD TEST MODE: Reduced delay for performance benchmarking
        try {
            logger.info("Mainframe: Processing transaction...");
            Thread.sleep(50); // 50ms delay (reduced from 2000ms for load testing)
        } catch (InterruptedException e) {
            logger.error("Mainframe processing interrupted", e);
            Thread.currentThread().interrupt();
        }

        // Generate fake authorization code and return success
        TransactionResponse response = TransactionResponse.success(request.getTransactionId());
        
        logger.info("Mainframe: Transaction processed successfully");
        logger.info("Authorization Code: {}", response.getAuthorizationCode());
        logger.info("==============================\n");
        
        return ResponseEntity.ok(response);
    }
}
