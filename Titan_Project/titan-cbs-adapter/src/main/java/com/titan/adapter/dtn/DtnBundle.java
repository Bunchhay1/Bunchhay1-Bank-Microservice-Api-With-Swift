package com.titan.adapter.dtn;

import java.time.Instant;
import java.util.UUID;

/**
 * DTN Bundle (RFC 5050 / RFC 9171)
 *
 * A self-contained, encrypted unit of data designed to survive
 * interplanetary delays (up to 22 minutes one-way, Mars-Earth).
 *
 * Custody flag: sender retains bundle until receiver ACK is received.
 * TTL: bundle expires if not delivered within the window.
 */
public class DtnBundle {

    public enum Status { PENDING, IN_FLIGHT, CUSTODY_ACCEPTED, DELIVERED, EXPIRED, FAILED }
    public enum Origin { EARTH, MARS, MOON, ORBITAL_STATION }

    private final String bundleId;
    private final String transactionId;
    private final String encryptedPayload;   // AES-256 encrypted TransferRequest JSON
    private final String payloadChecksum;    // SHA-256 of plaintext payload
    private final Origin sourceNode;
    private final String destinationEid;     // Endpoint Identifier e.g. "dtn://earth.titan/cbs"
    private final Instant createdAt;
    private final Instant expiresAt;         // createdAt + TTL (default 2 hours for Mars window)
    private final int custodyRetryCount;
    private Status status;
    private Instant lastAttemptAt;

    public DtnBundle(String transactionId, String encryptedPayload, String payloadChecksum,
                     Origin sourceNode, String destinationEid, long ttlSeconds) {
        this.bundleId = "dtn-bundle-" + UUID.randomUUID();
        this.transactionId = transactionId;
        this.encryptedPayload = encryptedPayload;
        this.payloadChecksum = payloadChecksum;
        this.sourceNode = sourceNode;
        this.destinationEid = destinationEid;
        this.createdAt = Instant.now();
        this.expiresAt = createdAt.plusSeconds(ttlSeconds);
        this.custodyRetryCount = 0;
        this.status = Status.PENDING;
    }

    public boolean isExpired() {
        return Instant.now().isAfter(expiresAt);
    }

    // Getters
    public String getBundleId()         { return bundleId; }
    public String getTransactionId()    { return transactionId; }
    public String getEncryptedPayload() { return encryptedPayload; }
    public String getPayloadChecksum()  { return payloadChecksum; }
    public Origin getSourceNode()       { return sourceNode; }
    public String getDestinationEid()   { return destinationEid; }
    public Instant getCreatedAt()       { return createdAt; }
    public Instant getExpiresAt()       { return expiresAt; }
    public int getCustodyRetryCount()   { return custodyRetryCount; }
    public Status getStatus()           { return status; }
    public Instant getLastAttemptAt()   { return lastAttemptAt; }

    public void setStatus(Status status)             { this.status = status; }
    public void setLastAttemptAt(Instant lastAttemptAt) { this.lastAttemptAt = lastAttemptAt; }
}
