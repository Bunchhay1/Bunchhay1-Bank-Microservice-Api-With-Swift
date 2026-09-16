package com.titan.adapter.dtn;

import com.titan.adapter.dto.json.TransferRequest;
import com.titan.adapter.dto.json.TransferResponse;
import com.titan.adapter.service.AdapterService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * DTN Controller — Interplanetary transfer endpoints
 *
 * POST /api/v1/dtn/bundle/send
 *   Mars (or any remote node) submits a transfer.
 *   Returns a bundleId immediately — the transfer is now in custody.
 *   The caller does NOT wait for Earth processing (fire-and-forget with guarantee).
 *
 * POST /api/v1/dtn/bundle/receive/{bundleId}
 *   Earth node re-entry: decrypts, verifies checksum, processes transfer.
 *   Called by the CustodyScheduler or manually when the contact window opens.
 *
 * GET  /api/v1/dtn/custody
 *   Operator view of all bundles currently in the custody store.
 */
@RestController
@RequestMapping("/api/v1/dtn")
public class DtnController {

    private static final Logger log = LoggerFactory.getLogger(DtnController.class);

    private final LtpEngine ltpEngine;
    private final AdapterService adapterService;

    public DtnController(LtpEngine ltpEngine, AdapterService adapterService) {
        this.ltpEngine = ltpEngine;
        this.adapterService = adapterService;
    }

    /**
     * Mars → Earth: bundle a transfer and hand it to LTP custody.
     */
    @PostMapping("/bundle/send")
    public ResponseEntity<Map<String, String>> sendBundle(
            @RequestBody TransferRequest request,
            @RequestParam(defaultValue = "MARS") DtnBundle.Origin origin,
            @RequestParam(defaultValue = "dtn://earth.titan/cbs") String destinationEid) {
        try {
            String bundleId = ltpEngine.createBundle(request, origin, destinationEid);
            log.info("[DTN] Bundle accepted into custody. id={} origin={}", bundleId, origin);
            return ResponseEntity.accepted().body(Map.of(
                    "bundleId", bundleId,
                    "status", "CUSTODY_ACCEPTED",
                    "message", "Bundle stored. Will be delivered when Earth contact window opens.",
                    "destinationEid", destinationEid
            ));
        } catch (Exception e) {
            log.error("[DTN] Failed to create bundle: {}", e.getMessage());
            return ResponseEntity.internalServerError().body(Map.of("error", e.getMessage()));
        }
    }

    /**
     * Earth re-entry: verify bundle integrity and process the transfer.
     */
    @PostMapping("/bundle/receive/{bundleId}")
    public ResponseEntity<TransferResponse> receiveBundle(@PathVariable String bundleId) {
        try {
            TransferRequest request = ltpEngine.receiveBundle(bundleId);
            log.info("[DTN] Bundle integrity verified. Processing transfer. txId={}", request.getTransactionId());

            TransferResponse response = adapterService.processTransfer(request);

            ltpEngine.acknowledgeCustody(bundleId);
            log.info("[DTN] Custody released. bundleId={}", bundleId);

            return ResponseEntity.ok(response);
        } catch (IllegalStateException e) {
            log.error("[DTN] Bundle delivery failed: {}", e.getMessage());
            return ResponseEntity.unprocessableEntity().build();
        } catch (Exception e) {
            log.error("[DTN] Unexpected error receiving bundle: {}", e.getMessage());
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Operator: view all bundles currently held in custody.
     */
    @GetMapping("/custody")
    public ResponseEntity<Map<String, Object>> getCustodyStore() {
        Map<String, DtnBundle> store = ltpEngine.getCustodyStore();
        return ResponseEntity.ok(Map.of(
                "bundleCount", store.size(),
                "bundles", store.entrySet().stream().map(e -> Map.of(
                        "bundleId", e.getKey(),
                        "transactionId", e.getValue().getTransactionId(),
                        "origin", e.getValue().getSourceNode(),
                        "status", e.getValue().getStatus(),
                        "expiresAt", e.getValue().getExpiresAt().toString()
                )).toList()
        ));
    }
}
