"""
Titan System Control Panel
==========================
FastAPI service that acts as the central DB control panel and reporting hub
for the entire Titan Banking platform.

Features:
  • Live DB dashboard — table row counts, sizes across all Titan databases
  • Risk event monitor — inspect all AI risk evaluations
  • Blocked transfer review — list, approve, reject blocked transactions
  • Transfer report viewer — daily/hourly aggregated summaries
  • System log viewer — operational audit trail
  • DB health check — ping all registered Titan databases
  • Manual report trigger — generate on-demand transfer reports

HTTP Endpoints (port 8090):
  GET  /health                              → service + DB health
  GET  /api/system/databases               → all Titan DB status
  GET  /api/system/databases/{db}/tables   → table stats for a given DB
  GET  /api/risk/events                    → paginated risk event log
  GET  /api/risk/events/stats              → aggregated stats
  GET  /api/risk/events/stats/daily        → per-day breakdown
  GET  /api/risk/blocked                   → blocked transfers
  PATCH /api/risk/blocked/{id}/review      → approve/reject a blocked transfer
  GET  /api/reports/transfer               → transfer_reports table
  POST /api/reports/transfer/generate      → trigger aggregation
  GET  /api/logs                           → system logs
  GET  /docs                               → Swagger UI
"""

import os
import json
import logging
import threading
from datetime import datetime, date, timedelta
from typing import Optional, List, Any, Dict

import psycopg2
import psycopg2.pool
from psycopg2.extras import RealDictCursor

from fastapi import FastAPI, HTTPException, Query, Path, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import uvicorn

# ─── Logging ──────────────────────────────────────────────────────────────────
LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO").upper()
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# ─── Configuration ────────────────────────────────────────────────────────────
HTTP_PORT   = int(os.environ.get("HTTP_PORT", "8090"))

# Primary DB — titan_systemdb
DB_HOST     = os.environ.get("DB_HOST",     "postgres")
DB_PORT     = int(os.environ.get("DB_PORT", "5432"))
DB_NAME     = os.environ.get("DB_NAME",     "titan_systemdb")
DB_USER     = os.environ.get("DB_USER",     "postgres")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "TitanDB$$ecure2026_X9z!Lp")

# ─── Registered Titan Databases (for the dashboard) ──────────────────────────
TITAN_DATABASES = {
    "titandb":       {"label": "Titan Core Banking",    "schema": "public"},
    "notificationdb": {"label": "Titan Notifications",  "schema": "public"},
    "promotiondb":   {"label": "Titan Promotions",      "schema": "public"},
    "loansdb":       {"label": "Titan Loans",           "schema": "public"},
    "titan_systemdb": {"label": "Titan System Control", "schema": "public"},
}

# ─── DB Connection Pool ───────────────────────────────────────────────────────
db_pool: Optional[psycopg2.pool.ThreadedConnectionPool] = None


def init_db_pool():
    global db_pool
    try:
        db_pool = psycopg2.pool.ThreadedConnectionPool(
            minconn=2,
            maxconn=15,
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
            connect_timeout=5,
        )
        logger.info(f"✅ DB pool ready → {DB_HOST}:{DB_PORT}/{DB_NAME}")
    except Exception as e:
        logger.error(f"❌ DB pool init failed: {e}")
        db_pool = None


def get_conn(dbname: Optional[str] = None):
    """Get a connection — either from pool (for titan_systemdb) or a new conn for other DBs."""
    if dbname is None or dbname == DB_NAME:
        if db_pool is None:
            return None
        try:
            return db_pool.getconn()
        except Exception as e:
            logger.error(f"getconn error: {e}")
            return None
    else:
        # Direct connection to another Titan DB (read-only queries only)
        try:
            return psycopg2.connect(
                host=DB_HOST,
                port=DB_PORT,
                dbname=dbname,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=5,
            )
        except Exception as e:
            logger.error(f"Direct connect to {dbname} failed: {e}")
            return None


def release_conn(conn, dbname: Optional[str] = None):
    if conn is None:
        return
    if dbname is None or dbname == DB_NAME:
        if db_pool:
            try:
                db_pool.putconn(conn)
            except Exception:
                pass
    else:
        try:
            conn.close()
        except Exception:
            pass


# ─── FastAPI App ──────────────────────────────────────────────────────────────
app = FastAPI(
    title="Titan System Control Panel",
    description=(
        "Central DB control panel and reporting hub for the Titan Banking platform. "
        "Provides DB health monitoring, risk event inspection, blocked transfer review, "
        "and aggregated reporting across all Titan microservices."
    ),
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ── Pydantic models ───────────────────────────────────────────────────────────
class BlockedTransferReview(BaseModel):
    reviewed_by: str
    review_status: str   # APPROVED | REJECTED
    review_notes: Optional[str] = None


class TableStat(BaseModel):
    table_name: str
    row_count: int
    table_size: str
    table_size_kb: int


class DatabaseStatus(BaseModel):
    database: str
    label: str
    connected: bool
    tables: Optional[List[TableStat]] = None
    error: Optional[str] = None


# ── Helpers ───────────────────────────────────────────────────────────────────
def _check_db_health(dbname: str) -> Dict[str, Any]:
    """Ping a database and return basic stats."""
    info = TITAN_DATABASES.get(dbname, {"label": dbname, "schema": "public"})
    conn = get_conn(dbname)
    if not conn:
        return {"database": dbname, "label": info["label"], "connected": False,
                "tables": None, "error": "Connection failed"}
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    relname AS table_name,
                    n_live_tup AS row_count,
                    pg_size_pretty(pg_total_relation_size(quote_ident(relname))) AS table_size,
                    pg_total_relation_size(quote_ident(relname)) / 1024 AS table_size_kb
                FROM pg_stat_user_tables
                ORDER BY n_live_tup DESC
                LIMIT 30
                """
            )
            tables = [dict(r) for r in cur.fetchall()]
        return {"database": dbname, "label": info["label"], "connected": True, "tables": tables, "error": None}
    except Exception as e:
        return {"database": dbname, "label": info["label"], "connected": False, "tables": None, "error": str(e)}
    finally:
        release_conn(conn, dbname)


def _snapshot_db(dbname: str):
    """Persist a row-count snapshot to db_snapshots."""
    info = _check_db_health(dbname)
    if not info["connected"] or not info["tables"]:
        return
    sys_conn = get_conn()
    if not sys_conn:
        return
    try:
        with sys_conn.cursor() as cur:
            for t in info["tables"]:
                cur.execute(
                    """
                    INSERT INTO db_snapshots (database_name, table_name, row_count, table_size_kb)
                    VALUES (%s, %s, %s, %s)
                    """,
                    (dbname, t["table_name"], t["row_count"], t["table_size_kb"])
                )
        sys_conn.commit()
    except Exception as e:
        logger.error(f"Snapshot error for {dbname}: {e}")
        try:
            sys_conn.rollback()
        except Exception:
            pass
    finally:
        release_conn(sys_conn)


# ── System / Health ───────────────────────────────────────────────────────────
@app.get("/health", tags=["System"])
def health():
    """Overall service liveness check."""
    conn = get_conn()
    db_ok = False
    if conn:
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
            db_ok = True
        except Exception:
            pass
        finally:
            release_conn(conn)
    return {
        "status": "ok" if db_ok else "degraded",
        "service": "titan-system",
        "version": "1.0.0",
        "db_connected": db_ok,
        "timestamp": datetime.utcnow().isoformat() + "Z"
    }


# ── Database Control Panel ────────────────────────────────────────────────────
@app.get("/api/system/databases", tags=["Database Control Panel"])
def list_databases():
    """
    Return health status + table stats for all registered Titan databases.
    This is the main DB control panel overview endpoint.
    """
    results = []
    threads = []

    def _probe(dbname):
        results.append(_check_db_health(dbname))

    for dbname in TITAN_DATABASES:
        t = threading.Thread(target=_probe, args=(dbname,))
        t.start()
        threads.append(t)
    for t in threads:
        t.join(timeout=10)

    # Sort: connected first
    results.sort(key=lambda x: (not x["connected"], x["database"]))
    connected = sum(1 for r in results if r["connected"])
    return {
        "summary": {
            "total_databases": len(TITAN_DATABASES),
            "connected": connected,
            "unreachable": len(TITAN_DATABASES) - connected,
            "checked_at": datetime.utcnow().isoformat() + "Z"
        },
        "databases": results
    }


@app.get("/api/system/databases/{dbname}/tables", tags=["Database Control Panel"])
def get_database_tables(
    dbname: str = Path(..., description="Database name, e.g. titandb")
):
    """Return detailed table statistics for a specific Titan database."""
    if dbname not in TITAN_DATABASES:
        raise HTTPException(
            status_code=404,
            detail=f"Database '{dbname}' not registered. "
                   f"Known databases: {list(TITAN_DATABASES.keys())}"
        )
    result = _check_db_health(dbname)
    if not result["connected"]:
        raise HTTPException(status_code=503, detail=result.get("error", "DB unavailable"))
    return result


@app.post("/api/system/snapshot", tags=["Database Control Panel"])
def snapshot_all_databases(background_tasks: BackgroundTasks):
    """Persist a point-in-time row count snapshot for all databases."""
    for dbname in TITAN_DATABASES:
        background_tasks.add_task(_snapshot_db, dbname)
    return {
        "status": "queued",
        "message": f"Snapshot job started for {len(TITAN_DATABASES)} databases"
    }


# ── Risk Events ───────────────────────────────────────────────────────────────
@app.get("/api/risk/events", tags=["Risk Monitor"])
def get_risk_events(
    page: int = Query(default=1, ge=1),
    size: int = Query(default=20, ge=1, le=100),
    user_id: Optional[str] = None,
    action: Optional[str] = Query(default=None, description="ALLOW | REVIEW | BLOCK"),
    level: Optional[str] = Query(default=None, description="LOW | MEDIUM | HIGH | BLOCKED"),
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
):
    """Paginated list of all risk evaluations from titan-ai-service."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        offset = (page - 1) * size
        filters, params = [], []

        if user_id:
            filters.append("user_id = %s");        params.append(user_id)
        if action:
            filters.append("action = %s");         params.append(action.upper())
        if level:
            filters.append("risk_level = %s");     params.append(level.upper())
        if from_date:
            filters.append("evaluated_at >= %s");  params.append(from_date)
        if to_date:
            filters.append("evaluated_at <= %s");  params.append(to_date)

        where = ("WHERE " + " AND ".join(filters)) if filters else ""

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(f"SELECT COUNT(*) AS total FROM risk_events {where}", params)
            total = cur.fetchone()["total"]
            cur.execute(
                f"""
                SELECT id, user_id, amount, risk_score, risk_level, action,
                       currency, transaction_ref, source_ip, evaluated_at
                FROM risk_events {where}
                ORDER BY evaluated_at DESC
                LIMIT %s OFFSET %s
                """,
                params + [size, offset]
            )
            rows = cur.fetchall()

        return {
            "page": page, "size": size, "total": total,
            "pages": (total + size - 1) // size if total else 0,
            "items": [{**r, "evaluated_at": r["evaluated_at"].isoformat()} for r in rows]
        }
    except Exception as e:
        logger.error(f"get_risk_events error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


@app.get("/api/risk/events/stats", tags=["Risk Monitor"])
def get_risk_stats(
    from_date: Optional[str] = None,
    to_date: Optional[str] = None,
):
    """Aggregated risk statistics across all evaluations."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        now = datetime.utcnow()
        dt_from = datetime.fromisoformat(from_date) if from_date else now - timedelta(days=30)
        dt_to   = datetime.fromisoformat(to_date)   if to_date   else now

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*)                                          AS total,
                    SUM(CASE WHEN action='ALLOW'  THEN 1 ELSE 0 END) AS allowed,
                    SUM(CASE WHEN action='REVIEW' THEN 1 ELSE 0 END) AS review,
                    SUM(CASE WHEN action='BLOCK'  THEN 1 ELSE 0 END) AS blocked,
                    COALESCE(SUM(amount), 0)                          AS total_amount,
                    COALESCE(SUM(CASE WHEN action='BLOCK' THEN amount ELSE 0 END), 0)
                                                                      AS blocked_amount,
                    COALESCE(ROUND(AVG(risk_score)::NUMERIC, 2), 0)  AS avg_score,
                    COALESCE(MAX(amount), 0)                          AS max_amount,
                    COUNT(DISTINCT user_id)                           AS unique_users
                FROM risk_events
                WHERE evaluated_at BETWEEN %s AND %s
                """,
                (dt_from, dt_to)
            )
            r = cur.fetchone()

        total = int(r["total"]) or 0
        blocked = int(r["blocked"]) or 0
        return {
            "period_from": dt_from.isoformat(),
            "period_to":   dt_to.isoformat(),
            "total_evaluations": total,
            "allowed_count": int(r["allowed"]),
            "review_count":  int(r["review"]),
            "blocked_count": blocked,
            "total_amount_evaluated": float(r["total_amount"]),
            "blocked_amount": float(r["blocked_amount"]),
            "avg_risk_score": float(r["avg_score"]),
            "max_single_amount": float(r["max_amount"]),
            "unique_users": int(r["unique_users"]),
            "block_rate_pct": round(blocked / total * 100, 2) if total else 0.0
        }
    except Exception as e:
        logger.error(f"get_risk_stats error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


@app.get("/api/risk/events/stats/daily", tags=["Risk Monitor"])
def get_risk_stats_daily(days: int = Query(default=7, ge=1, le=90)):
    """Daily breakdown of risk evaluations for the last N days."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    DATE(evaluated_at)                               AS report_date,
                    COUNT(*)                                         AS total,
                    SUM(CASE WHEN action='ALLOW'  THEN 1 ELSE 0 END) AS allowed,
                    SUM(CASE WHEN action='REVIEW' THEN 1 ELSE 0 END) AS review,
                    SUM(CASE WHEN action='BLOCK'  THEN 1 ELSE 0 END) AS blocked,
                    COALESCE(SUM(amount), 0)                          AS total_amount,
                    COALESCE(ROUND(AVG(risk_score)::NUMERIC, 2), 0)  AS avg_score,
                    COUNT(DISTINCT user_id)                           AS unique_users
                FROM risk_events
                WHERE evaluated_at >= NOW() - (%s || ' days')::INTERVAL
                GROUP BY DATE(evaluated_at)
                ORDER BY report_date DESC
                """,
                (days,)
            )
            rows = cur.fetchall()

        return {
            "days": days,
            "items": [
                {
                    "report_date": r["report_date"].isoformat(),
                    "total": int(r["total"]),
                    "allowed": int(r["allowed"]),
                    "review": int(r["review"]),
                    "blocked": int(r["blocked"]),
                    "total_amount": float(r["total_amount"]),
                    "avg_score": float(r["avg_score"]),
                    "unique_users": int(r["unique_users"]),
                }
                for r in rows
            ]
        }
    except Exception as e:
        logger.error(f"get_risk_stats_daily error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


# ── Blocked Transfers ─────────────────────────────────────────────────────────
@app.get("/api/risk/blocked", tags=["Blocked Transfers"])
def get_blocked_transfers(
    page: int = Query(default=1, ge=1),
    size: int = Query(default=20, ge=1, le=100),
    user_id: Optional[str] = None,
    review_status: Optional[str] = Query(default=None, description="PENDING | APPROVED | REJECTED"),
):
    """Paginated list of blocked high-value transfers (>= $10,000)."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        offset = (page - 1) * size
        filters, params = [], []
        if user_id:
            filters.append("user_id = %s");        params.append(user_id)
        if review_status:
            filters.append("review_status = %s");  params.append(review_status.upper())

        where = ("WHERE " + " AND ".join(filters)) if filters else ""

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(f"SELECT COUNT(*) AS total FROM blocked_transfers {where}", params)
            total = cur.fetchone()["total"]
            cur.execute(
                f"""
                SELECT id, user_id, amount, currency, risk_score, block_reason,
                       transaction_ref, source_ip, review_status,
                       reviewed_by, review_notes, blocked_at, reviewed_at
                FROM blocked_transfers {where}
                ORDER BY blocked_at DESC
                LIMIT %s OFFSET %s
                """,
                params + [size, offset]
            )
            rows = cur.fetchall()

        def _fmt(r):
            d = dict(r)
            d["blocked_at"]  = d["blocked_at"].isoformat()
            d["reviewed_at"] = d["reviewed_at"].isoformat() if d["reviewed_at"] else None
            return d

        return {
            "page": page, "size": size, "total": total,
            "pages": (total + size - 1) // size if total else 0,
            "items": [_fmt(r) for r in rows]
        }
    except Exception as e:
        logger.error(f"get_blocked_transfers error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


@app.patch("/api/risk/blocked/{blocked_id}/review", tags=["Blocked Transfers"])
def review_blocked_transfer(
    blocked_id: int = Path(..., description="Blocked transfer ID"),
    body: BlockedTransferReview = ...,
):
    """
    Approve or reject a blocked transfer.
    Sets review_status to APPROVED or REJECTED and records the reviewer.
    """
    if body.review_status not in ("APPROVED", "REJECTED"):
        raise HTTPException(status_code=400, detail="review_status must be APPROVED or REJECTED")

    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute("SELECT id FROM blocked_transfers WHERE id = %s", (blocked_id,))
            if not cur.fetchone():
                raise HTTPException(status_code=404, detail=f"Blocked transfer {blocked_id} not found")

            cur.execute(
                """
                UPDATE blocked_transfers
                SET review_status = %s,
                    reviewed_by   = %s,
                    review_notes  = %s,
                    reviewed_at   = NOW()
                WHERE id = %s
                RETURNING id, user_id, amount, review_status, reviewed_by, reviewed_at
                """,
                (body.review_status, body.reviewed_by, body.review_notes, blocked_id)
            )
            updated = cur.fetchone()
        conn.commit()

        return {
            "status": "updated",
            "blocked_transfer": {
                **dict(updated),
                "reviewed_at": updated["reviewed_at"].isoformat()
            }
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"review_blocked_transfer error: {e}")
        try:
            conn.rollback()
        except Exception:
            pass
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


# ── Transfer Reports ──────────────────────────────────────────────────────────
@app.get("/api/reports/transfer", tags=["Transfer Reports"])
def get_transfer_reports(
    period_type: Optional[str] = Query(default=None, description="DAILY | HOURLY"),
    limit: int = Query(default=30, ge=1, le=365),
):
    """Return aggregated transfer reports from titan-ai-service."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        filters, params = [], []
        if period_type:
            filters.append("period_type = %s");    params.append(period_type.upper())

        where = ("WHERE " + " AND ".join(filters)) if filters else ""

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                f"""
                SELECT id, report_period, period_type, total_transactions,
                       total_amount, allowed_count, review_count, blocked_count,
                       avg_risk_score, max_amount, min_amount, unique_users,
                       generated_at
                FROM transfer_reports {where}
                ORDER BY report_period DESC
                LIMIT %s
                """,
                params + [limit]
            )
            rows = cur.fetchall()

        def _fmt(r):
            d = dict(r)
            d["generated_at"] = d["generated_at"].isoformat()
            d["total_amount"] = float(d["total_amount"])
            d["avg_risk_score"] = float(d["avg_risk_score"])
            d["max_amount"] = float(d["max_amount"])
            d["min_amount"] = float(d["min_amount"])
            return d

        return {"count": len(rows), "items": [_fmt(r) for r in rows]}
    except Exception as e:
        logger.error(f"get_transfer_reports error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


@app.post("/api/reports/transfer/generate", tags=["Transfer Reports"])
def generate_transfer_report(background_tasks: BackgroundTasks):
    """Trigger daily transfer report aggregation manually."""
    background_tasks.add_task(_aggregate_daily_report)
    return {"status": "queued", "message": "Transfer report aggregation started"}


def _aggregate_daily_report():
    """Aggregate today's risk_events into transfer_reports."""
    conn = get_conn()
    if not conn:
        logger.warning("Daily report skipped — no DB")
        return
    try:
        today = date.today().isoformat()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(
                """
                SELECT
                    COUNT(*)                              AS total_transactions,
                    COALESCE(SUM(amount), 0)              AS total_amount,
                    SUM(CASE WHEN action='ALLOW'  THEN 1 ELSE 0 END) AS allowed_count,
                    SUM(CASE WHEN action='REVIEW' THEN 1 ELSE 0 END) AS review_count,
                    SUM(CASE WHEN action='BLOCK'  THEN 1 ELSE 0 END) AS blocked_count,
                    COALESCE(ROUND(AVG(risk_score)::NUMERIC, 2), 0)  AS avg_risk_score,
                    COALESCE(MAX(amount), 0)              AS max_amount,
                    COALESCE(MIN(amount), 0)              AS min_amount,
                    COUNT(DISTINCT user_id)               AS unique_users
                FROM risk_events
                WHERE DATE(evaluated_at) = %s
                """,
                (today,)
            )
            row = cur.fetchone()

            cur.execute(
                """
                INSERT INTO transfer_reports
                    (report_period, period_type, total_transactions, total_amount,
                     allowed_count, review_count, blocked_count, avg_risk_score,
                     max_amount, min_amount, unique_users)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (report_period, period_type) DO UPDATE SET
                    total_transactions = EXCLUDED.total_transactions,
                    total_amount       = EXCLUDED.total_amount,
                    allowed_count      = EXCLUDED.allowed_count,
                    review_count       = EXCLUDED.review_count,
                    blocked_count      = EXCLUDED.blocked_count,
                    avg_risk_score     = EXCLUDED.avg_risk_score,
                    max_amount         = EXCLUDED.max_amount,
                    min_amount         = EXCLUDED.min_amount,
                    unique_users       = EXCLUDED.unique_users,
                    generated_at       = NOW()
                """,
                (today, "DAILY",
                 row["total_transactions"], float(row["total_amount"]),
                 row["allowed_count"], row["review_count"], row["blocked_count"],
                 float(row["avg_risk_score"]), float(row["max_amount"]),
                 float(row["min_amount"]), row["unique_users"])
            )
        conn.commit()
        logger.info(f"✅ Daily transfer report generated for {today}")
    except Exception as e:
        logger.error(f"Daily report aggregation error: {e}")
        try:
            conn.rollback()
        except Exception:
            pass
    finally:
        release_conn(conn)


# ── System Logs ───────────────────────────────────────────────────────────────
@app.get("/api/logs", tags=["System Logs"])
def get_system_logs(
    page: int = Query(default=1, ge=1),
    size: int = Query(default=50, ge=1, le=200),
    service: Optional[str] = None,
    level: Optional[str] = Query(default=None, description="INFO | WARN | ERROR | AUDIT"),
    category: Optional[str] = Query(default=None, description="TRANSFER | RISK | DB | REPORT | ADMIN"),
):
    """Return paginated system audit logs."""
    conn = get_conn()
    if not conn:
        raise HTTPException(status_code=503, detail="Database unavailable")
    try:
        offset = (page - 1) * size
        filters, params = [], []
        if service:
            filters.append("service = %s");    params.append(service)
        if level:
            filters.append("level = %s");      params.append(level.upper())
        if category:
            filters.append("category = %s");   params.append(category.upper())

        where = ("WHERE " + " AND ".join(filters)) if filters else ""

        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            cur.execute(f"SELECT COUNT(*) AS total FROM system_logs {where}", params)
            total = cur.fetchone()["total"]
            cur.execute(
                f"""
                SELECT id, service, level, category, message, details, created_at
                FROM system_logs {where}
                ORDER BY created_at DESC
                LIMIT %s OFFSET %s
                """,
                params + [size, offset]
            )
            rows = cur.fetchall()

        return {
            "page": page, "size": size, "total": total,
            "pages": (total + size - 1) // size if total else 0,
            "items": [
                {**r, "created_at": r["created_at"].isoformat()}
                for r in rows
            ]
        }
    except Exception as e:
        logger.error(f"get_system_logs error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_conn(conn)


# ─── Startup / Shutdown events ─────────────────────────────────────────────────
@app.on_event("startup")
def on_startup():
    logger.info("=" * 60)
    logger.info("🏦 Titan System Control Panel starting...")
    logger.info(f"   HTTP Port    : {HTTP_PORT}")
    logger.info(f"   Primary DB   : {DB_HOST}:{DB_PORT}/{DB_NAME}")
    logger.info(f"   Monitored DBs: {', '.join(TITAN_DATABASES.keys())}")
    logger.info("=" * 60)
    init_db_pool()


@app.on_event("shutdown")
def on_shutdown():
    if db_pool:
        db_pool.closeall()
    logger.info("Titan System Control Panel stopped.")


# ─── Entry Point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=HTTP_PORT,
        log_level=LOG_LEVEL.lower(),
        access_log=True,
        reload=False,
    )
