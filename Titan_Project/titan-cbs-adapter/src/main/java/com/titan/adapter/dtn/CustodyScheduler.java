package com.titan.adapter.dtn;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.Map;

/**
 * Custody Reaper — scans the custody store every 60 seconds.
 *
 * - Logs bundles still in-flight (waiting out the light-speed delay)
 * - Marks expired bundles so operators can investigate
 *
 * In a real DTN node this would also trigger retransmission
 * once the contact window with the destination node opens.
 */
@Component
public class CustodyScheduler {

    private static final Logger log = LoggerFactory.getLogger(CustodyScheduler.class);

    private final LtpEngine ltpEngine;

    public CustodyScheduler(LtpEngine ltpEngine) {
        this.ltpEngine = ltpEngine;
    }

    @Scheduled(fixedDelay = 60_000)
    public void sweepCustodyStore() {
        Map<String, DtnBundle> store = ltpEngine.getCustodyStore();
        if (store.isEmpty()) return;

        log.info("[DTN-Custody] Sweeping {} bundle(s) in custody store.", store.size());
        Instant now = Instant.now();

        store.forEach((id, bundle) -> {
            if (bundle.isExpired()) {
                bundle.setStatus(DtnBundle.Status.EXPIRED);
                log.warn("[DTN-Custody] EXPIRED bundle detected. id={} txId={} origin={} expiredAt={}",
                        id, bundle.getTransactionId(), bundle.getSourceNode(), bundle.getExpiresAt());
            } else {
                long secondsRemaining = bundle.getExpiresAt().getEpochSecond() - now.getEpochSecond();
                log.info("[DTN-Custody] IN-FLIGHT bundle. id={} txId={} origin={} status={} ttlRemaining={}s",
                        id, bundle.getTransactionId(), bundle.getSourceNode(), bundle.getStatus(), secondsRemaining);
            }
        });
    }
}
