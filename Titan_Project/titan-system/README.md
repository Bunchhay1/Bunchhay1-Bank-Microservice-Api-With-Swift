# Titan System — DB Control Panel & Banking Report Service

Central control panel and reporting hub for the Titan Banking platform.
Provides live database health monitoring, risk event inspection, high-value
transfer blocking audit, and aggregated transfer reporting across all services.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Titan Banking Platform                                          │
│                                                                  │
│  ┌─────────────────┐   gRPC CheckRisk   ┌────────────────────┐  │
│  │ titan-core-     │──────────────────► │ titan-ai-service   │  │
│  │ banking :8080   │                    │  gRPC  :50051      │  │
│  └─────────────────┘                    │  HTTP  :8085       │  │
│                                         └────────┬───────────┘  │
│  ┌─────────────────┐                             │ persist      │
│  │ titan-system    │◄────────────────────────────┘ risk_events  │
│  │ :8090           │                             │ blocked_transfers
│  │ (Control Panel) │◄──── read all titan DBs ───┘              │
│  └─────────────────┘                                            │
│         │                                                        │
│         ▼                                                        │
│  ┌─────────────────┐                                            │
│  │ PostgreSQL       │  titan_systemdb                           │
│  │ :5432            │  ├─ risk_events                           │
│  │                  │  ├─ blocked_transfers                     │
│  │                  │  ├─ transfer_reports                      │
│  │                  │  ├─ system_logs                           │
│  │                  │  └─ db_snapshots                          │
│  └─────────────────┘                                            │
└─────────────────────────────────────────────────────────────────┘
```

---

## Services

### titan-ai-service (enhanced)

**Ports:** `50051` (gRPC) · `8085` (HTTP)

Dual-mode service — gRPC for risk scoring, HTTP for reports.

**High-value transfer rule:**

| Amount        | Score | Level   | Action |
|---------------|-------|---------|--------|
| < $1,000      | 10    | LOW     | ALLOW  |
| $1,000–$9,999 | 50    | MEDIUM  | REVIEW |
| ≥ $10,000     | 100   | BLOCKED | **BLOCK** ⛔ |

Every evaluation is persisted to `titan_systemdb.risk_events`.
Every BLOCK is additionally written to `titan_systemdb.blocked_transfers`.

**HTTP Endpoints:**

```
GET  /health                         → service liveness
GET  /api/reports/risk               → paginated risk event log
GET  /api/reports/blocked            → blocked transfers log
GET  /api/reports/stats              → aggregated stats (30-day default)
GET  /api/reports/stats/daily        → per-day breakdown (last 7 days)
POST /api/reports/generate           → trigger daily report aggregation
GET  /docs                           → Swagger UI
```

---

### titan-system (control panel)

**Port:** `8090`

Central DB control panel. Reads from `titan_systemdb` and also probes all
other Titan databases (`titandb`, `notificationdb`, `promotiondb`, `loansdb`)
to provide a unified view of database health and table statistics.

**HTTP Endpoints:**

```
# System
GET  /health                                    → service + DB liveness

# Database Control Panel
GET  /api/system/databases                      → health + table stats for ALL Titan DBs
GET  /api/system/databases/{dbname}/tables      → table stats for one DB
POST /api/system/snapshot                       → persist row-count snapshot for all DBs

# Risk Monitor
GET  /api/risk/events                           → paginated risk evaluations
GET  /api/risk/events/stats                     → aggregated risk stats
GET  /api/risk/events/stats/daily               → per-day breakdown

# Blocked Transfer Review (AML/Compliance)
GET  /api/risk/blocked                          → list blocked transfers
PATCH /api/risk/blocked/{id}/review             → approve / reject a blocked transfer

# Transfer Reports
GET  /api/reports/transfer                      → aggregated transfer reports
POST /api/reports/transfer/generate             → trigger report aggregation

# Audit Logs
GET  /api/logs                                  → system audit log

# Swagger
GET  /docs                                      → Swagger UI
GET  /redoc                                     → ReDoc UI
```

---

## Database Schema — `titan_systemdb`

```sql
risk_events          -- every gRPC risk evaluation (user_id, amount, score, action)
blocked_transfers    -- high-value transfers that were blocked (≥ $10,000)
transfer_reports     -- daily/hourly aggregated summaries
system_logs          -- operational audit trail (service, level, category, message)
db_snapshots         -- point-in-time row/size snapshots of all Titan tables
```

---

## Quick Start

```bash
# Start the full dev stack (includes titan-ai-service + titan-system)
docker compose -f docker-compose-devV1.yml up -d --build

# Check titan-system health
curl http://localhost:8090/health

# View all Titan databases (DB control panel)
curl http://localhost:8090/api/system/databases | jq .

# Check recent risk evaluations
curl http://localhost:8085/api/reports/risk | jq .

# Check blocked high-value transfers
curl http://localhost:8090/api/risk/blocked | jq .

# Aggregated risk stats (last 30 days)
curl http://localhost:8085/api/reports/stats | jq .

# Per-day breakdown (last 7 days)
curl http://localhost:8090/api/risk/events/stats/daily | jq .

# Approve a blocked transfer (ID=1)
curl -X PATCH http://localhost:8090/api/risk/blocked/1/review \
     -H "Content-Type: application/json" \
     -d '{"reviewed_by": "compliance_admin", "review_status": "APPROVED", "review_notes": "Verified with customer"}'
```

---

## Testing the High-Value Block Rule

Use `grpcurl` or any gRPC client to call `titan-ai-service`:

```bash
# Install grpcurl if needed: brew install grpcurl

# Transfer $500 → ALLOW
grpcurl -plaintext -d '{"user_id":"user123","amount":500}' \
  localhost:50051 risk_engine.RiskEngineService/CheckRisk

# Transfer $5,000 → REVIEW
grpcurl -plaintext -d '{"user_id":"user123","amount":5000}' \
  localhost:50051 risk_engine.RiskEngineService/CheckRisk

# Transfer $15,000 → BLOCK ⛔ (high-value rule)
grpcurl -plaintext -d '{"user_id":"user123","amount":15000}' \
  localhost:50051 risk_engine.RiskEngineService/CheckRisk

# Then check the blocked transfers were recorded:
curl http://localhost:8090/api/risk/blocked | jq .
```

---

## Environment Variables

### titan-ai-service

| Variable             | Default                      | Description                         |
|----------------------|------------------------------|-------------------------------------|
| `GRPC_PORT`          | `50051`                      | gRPC listen port                    |
| `HTTP_PORT`          | `8085`                       | FastAPI HTTP listen port             |
| `RISK_LOW_MAX_AMOUNT`| `1000`                       | Max amount for LOW risk              |
| `RISK_BLOCK_THRESHOLD`| `10000`                     | Amount at which transfers are BLOCKED|
| `DB_ENABLED`         | `true`                       | Toggle DB persistence                |
| `DB_HOST`            | `postgres`                   | PostgreSQL host                     |
| `DB_NAME`            | `titan_systemdb`             | Target database                     |
| `DB_USER`            | `postgres`                   | DB username                         |
| `DB_PASSWORD`        | *(see docker-compose)*       | DB password                         |

### titan-system

| Variable    | Default          | Description              |
|-------------|------------------|--------------------------|
| `HTTP_PORT` | `8090`           | HTTP listen port         |
| `DB_HOST`   | `postgres`       | PostgreSQL host          |
| `DB_NAME`   | `titan_systemdb` | Primary database         |
| `DB_USER`   | `postgres`       | DB username              |
| `DB_PASSWORD`| *(see docker-compose)* | DB password        |

---

## File Structure

```
titan-system/
├── main.py          # FastAPI control panel service
├── schema.sql       # titan_systemdb DDL
├── requirements.txt # Python dependencies
├── Dockerfile       # Container definition
└── README.md        # This file

titan-ai-service/
├── main.py          # gRPC + HTTP dual-mode service (enhanced)
├── requirements.txt # Python dependencies (added FastAPI, psycopg2)
├── Dockerfile       # Exposes 50051 + 8085
├── risk_engine.proto
└── protos/
    ├── risk_engine_pb2.py
    └── risk_engine_pb2_grpc.py

init-db/
├── 01-create-databases.sql        # creates titan_systemdb (added)
├── 02-notification-schema.sql
└── (titan-system/schema.sql mounted as 03-titan-system-schema.sql)
```
