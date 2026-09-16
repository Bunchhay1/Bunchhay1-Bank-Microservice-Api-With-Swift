package com.titan.adapter.iso20022;

import jakarta.xml.bind.JAXBException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;

/**
 * Task 1: ISO 20022 REST endpoints
 * POST /api/v1/iso20022/pacs008   — generate outbound SWIFT wire XML
 * POST /api/v1/iso20022/camt053   — parse inbound bank statement XML
 */
@RestController
@RequestMapping("/api/v1/iso20022")
@RequiredArgsConstructor
@Slf4j
public class Iso20022Controller {

    private final Iso20022MessageService iso20022MessageService;

    @PostMapping(value = "/pacs008", produces = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<String> generatePacs008(@RequestBody Iso20022MessageService.Iso20022TransferRequest req) {
        try {
            String xml = iso20022MessageService.buildPacs008(req);
            return ResponseEntity.ok(xml);
        } catch (JAXBException e) {
            log.error("Failed to generate pacs.008", e);
            return ResponseEntity.internalServerError().body("<error>" + e.getMessage() + "</error>");
        }
    }

    @PostMapping(value = "/camt053/parse", consumes = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<Camt053Document> parseCamt053(@RequestBody String xml) {
        try {
            return ResponseEntity.ok(iso20022MessageService.parseCamt053(xml));
        } catch (JAXBException e) {
            log.error("Failed to parse camt.053", e);
            return ResponseEntity.badRequest().build();
        }
    }

    @PostMapping(value = "/pacs008/parse", consumes = MediaType.APPLICATION_XML_VALUE)
    public ResponseEntity<Pacs008Document> parsePacs008(@RequestBody String xml) {
        try {
            return ResponseEntity.ok(iso20022MessageService.parsePacs008(xml));
        } catch (JAXBException e) {
            log.error("Failed to parse pacs.008", e);
            return ResponseEntity.badRequest().build();
        }
    }
}
