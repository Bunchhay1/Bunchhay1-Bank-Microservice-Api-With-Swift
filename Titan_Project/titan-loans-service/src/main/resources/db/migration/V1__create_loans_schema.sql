-- =============================================================================
-- V1__create_loans_schema.sql
-- Titan Loans Service — initial schema
-- =============================================================================

-- ── Loans table ───────────────────────────────────────────────────────────────
CREATE TABLE loans (
    id              BIGSERIAL       PRIMARY KEY,
    account_id      BIGINT          NOT NULL,                   -- FK into titan-core-banking (cross-service ref)
    account_number  VARCHAR(50)     NOT NULL,
    username        VARCHAR(100)    NOT NULL,
    amount          DECIMAL(19, 2)  NOT NULL,
    interest_rate   DECIMAL(5, 4)   NOT NULL,                   -- e.g. 0.0500 = 5%
    term_months     INTEGER         NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'PENDING', -- PENDING | APPROVED | REJECTED | ACTIVE | PAID | OVERDUE
    note            TEXT,
    applied_at      TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    approved_at     TIMESTAMP,
    rejected_at     TIMESTAMP
);

CREATE INDEX idx_loans_username        ON loans (username);
CREATE INDEX idx_loans_account_id      ON loans (account_id);
CREATE INDEX idx_loans_account_number  ON loans (account_number);
CREATE INDEX idx_loans_status          ON loans (status);

-- ── Loan repayments (amortization schedule) ───────────────────────────────────
CREATE TABLE loan_repayments (
    id          BIGSERIAL       PRIMARY KEY,
    loan_id     BIGINT          NOT NULL REFERENCES loans (id) ON DELETE CASCADE,
    due_date    TIMESTAMP       NOT NULL,
    amount      DECIMAL(19, 2)  NOT NULL,
    status      VARCHAR(20)     NOT NULL DEFAULT 'PENDING',     -- PENDING | PAID
    paid_date   TIMESTAMP
);

CREATE INDEX idx_loan_repayments_loan_id ON loan_repayments (loan_id);
CREATE INDEX idx_loan_repayments_status  ON loan_repayments (status);
