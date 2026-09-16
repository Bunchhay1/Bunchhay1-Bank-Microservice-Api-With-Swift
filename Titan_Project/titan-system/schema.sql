-- =============================================================================
-- schema.sql — titan_systemdb
-- Titan System Control Panel database schema
--
-- Tables:
--   risk_events        — every gRPC risk check recorded by titan-ai-service
--   blocked_transfers  — transfers blocked due to high-value rule (>= $10,000)
--   transfer_reports   — daily/hourly aggregated summaries
--   system_logs        — service-level audit and operational logs
-- =============================================================================

\connect titan_systemdb;

-- ──────────────────────────────────────────────────────────────────────────────
-- RISK EVENTS
-- Records every risk evaluation made by titan-ai-service
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS risk_events (
    id              BIGSERIAL PRIMARY KEY,
    user_id         VARCHAR(255)     NOT NULL,
    amount          NUMERIC(18, 2)   NOT NULL,
    risk_score      INTEGER          NOT NULL,
    risk_level      VARCHAR(20)      NOT NULL,   -- LOW | MEDIUM | HIGH | BLOCKED
    action          VARCHAR(20)      NOT NULL,   -- ALLOW | REVIEW | BLOCK
    source_ip       VARCHAR(45),
    currency        VARCHAR(10)      DEFAULT 'USD',
    transaction_ref VARCHAR(255),
    evaluated_at    TIMESTAMP        NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_risk_events_user       ON risk_events(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_events_level      ON risk_events(risk_level);
CREATE INDEX IF NOT EXISTS idx_risk_events_action     ON risk_events(action);
CREATE INDEX IF NOT EXISTS idx_risk_events_evaluated  ON risk_events(evaluated_at DESC);

-- ──────────────────────────────────────────────────────────────────────────────
-- BLOCKED TRANSFERS
-- Dedicated table for every blocked transaction (>= $10,000)
-- Provides fast audit trail for compliance/AML teams
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS blocked_transfers (
    id              BIGSERIAL PRIMARY KEY,
    user_id         VARCHAR(255)     NOT NULL,
    amount          NUMERIC(18, 2)   NOT NULL,
    currency        VARCHAR(10)      DEFAULT 'USD',
    risk_score      INTEGER          NOT NULL,
    block_reason    VARCHAR(500)     NOT NULL,
    transaction_ref VARCHAR(255),
    source_ip       VARCHAR(45),
    reviewed_by     VARCHAR(255),                 -- admin who reviewed (nullable)
    review_status   VARCHAR(20)      DEFAULT 'PENDING',  -- PENDING | APPROVED | REJECTED
    review_notes    TEXT,
    blocked_at      TIMESTAMP        NOT NULL DEFAULT NOW(),
    reviewed_at     TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_blocked_user        ON blocked_transfers(user_id);
CREATE INDEX IF NOT EXISTS idx_blocked_amount      ON blocked_transfers(amount DESC);
CREATE INDEX IF NOT EXISTS idx_blocked_status      ON blocked_transfers(review_status);
CREATE INDEX IF NOT EXISTS idx_blocked_at          ON blocked_transfers(blocked_at DESC);

-- ──────────────────────────────────────────────────────────────────────────────
-- TRANSFER REPORTS
-- Aggregated summaries written by titan-system on schedule
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS transfer_reports (
    id                  BIGSERIAL PRIMARY KEY,
    report_period       VARCHAR(50)      NOT NULL,   -- e.g. '2026-08-29' or '2026-08-29T15:00'
    period_type         VARCHAR(10)      NOT NULL,   -- DAILY | HOURLY
    total_transactions  INTEGER          NOT NULL DEFAULT 0,
    total_amount        NUMERIC(22, 2)   NOT NULL DEFAULT 0,
    allowed_count       INTEGER          NOT NULL DEFAULT 0,
    review_count        INTEGER          NOT NULL DEFAULT 0,
    blocked_count       INTEGER          NOT NULL DEFAULT 0,
    avg_risk_score      NUMERIC(6, 2)    NOT NULL DEFAULT 0,
    max_amount          NUMERIC(18, 2)   NOT NULL DEFAULT 0,
    min_amount          NUMERIC(18, 2)   NOT NULL DEFAULT 0,
    unique_users        INTEGER          NOT NULL DEFAULT 0,
    generated_at        TIMESTAMP        NOT NULL DEFAULT NOW(),
    UNIQUE(report_period, period_type)
);

CREATE INDEX IF NOT EXISTS idx_report_period      ON transfer_reports(report_period DESC);
CREATE INDEX IF NOT EXISTS idx_report_type        ON transfer_reports(period_type);

-- ──────────────────────────────────────────────────────────────────────────────
-- SYSTEM LOGS
-- Operational and audit log entries from titan-system itself
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS system_logs (
    id          BIGSERIAL PRIMARY KEY,
    service     VARCHAR(100)     NOT NULL,   -- e.g. 'titan-ai-service', 'titan-system'
    level       VARCHAR(10)      NOT NULL,   -- INFO | WARN | ERROR | AUDIT
    category    VARCHAR(50)      NOT NULL,   -- TRANSFER | RISK | DB | REPORT | ADMIN
    message     TEXT             NOT NULL,
    details     JSONB,                        -- structured metadata
    created_at  TIMESTAMP        NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_syslog_service    ON system_logs(service);
CREATE INDEX IF NOT EXISTS idx_syslog_level      ON system_logs(level);
CREATE INDEX IF NOT EXISTS idx_syslog_category   ON system_logs(category);
CREATE INDEX IF NOT EXISTS idx_syslog_created    ON system_logs(created_at DESC);

-- ──────────────────────────────────────────────────────────────────────────────
-- DATABASE SNAPSHOTS
-- Stores point-in-time snapshots of database table counts (control panel data)
-- ──────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS db_snapshots (
    id              BIGSERIAL PRIMARY KEY,
    database_name   VARCHAR(100)     NOT NULL,
    table_name      VARCHAR(100)     NOT NULL,
    row_count       BIGINT           NOT NULL DEFAULT 0,
    table_size_kb   BIGINT           NOT NULL DEFAULT 0,
    snapshot_at     TIMESTAMP        NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_snapshot_db        ON db_snapshots(database_name);
CREATE INDEX IF NOT EXISTS idx_snapshot_at        ON db_snapshots(snapshot_at DESC);

-- ──────────────────────────────────────────────────────────────────────────────
-- Seed: insert a startup log entry
-- ──────────────────────────────────────────────────────────────────────────────
INSERT INTO system_logs (service, level, category, message, details)
VALUES (
    'titan-system',
    'INFO',
    'ADMIN',
    'titan_systemdb schema initialized',
    '{"version": "1.0", "tables": ["risk_events", "blocked_transfers", "transfer_reports", "system_logs", "db_snapshots"]}'
);
