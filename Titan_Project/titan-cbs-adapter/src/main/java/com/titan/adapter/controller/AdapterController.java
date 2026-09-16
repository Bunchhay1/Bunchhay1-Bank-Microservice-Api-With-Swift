package com.titan.adapter.controller;

import com.titan.adapter.dto.json.TransferRequest;
import com.titan.adapter.dto.json.TransferResponse;
import com.titan.adapter.service.AdapterService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/adapter")
public class AdapterController {
    
    private static final Logger logger = LoggerFactory.getLogger(AdapterController.class);
    
    private final AdapterService adapterService;

    public AdapterController(AdapterService adapterService) {
        this.adapterService = adapterService;
    }

    @PostMapping(value = "/transfer", 
                consumes = MediaType.APPLICATION_JSON_VALUE, 
                produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<TransferResponse> processTransfer(@RequestBody TransferRequest request) {
        logger.info("=== TITAN GATEWAY: RECEIVING CLEAN JSON REQUEST ===");
        logger.info("Endpoint: POST /api/v1/adapter/transfer");
        logger.info("Content-Type: application/json");
        logger.info("Request Body: {}", request);
        logger.info("================================================\n");
        
        TransferResponse response = adapterService.processTransfer(request);
        
        logger.info("=== TITAN GATEWAY: RETURNING CLEAN JSON RESPONSE ===");
        logger.info("Response: {}", response);
        logger.info("====================================================\n");
        
        return ResponseEntity.ok(response);
    }

    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("{\"status\":\"UP\",\"service\":\"titan-cbs-adapter\",\"gateway\":\"Anti-Corruption-Layer\"}");
    }
}
