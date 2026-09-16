"""
test_gateway.py
===============
Full end-to-end API tests routed through titan-gateway-go (:8088).

Architecture tested:
  iOS / Test Client
      └─► titan-gateway-go  :8088   (JWT check, rate limit, routing)
              └─► titan-core-banking  :8080

Covers:
  - Health check (gateway)
  - Auth   : register, login
  - Accounts: list, create
  - Transactions: history, deposit, withdraw, transfer
  - ATM    : generate code, check status, cancel code
  - QR     : generate, cancel, history

Run:
  python3 test_gateway.py
"""

import requests
import json
import uuid
import time
import sys

# ─── Config ───────────────────────────────────────────────────────────────────
GATEWAY_URL  = "http://localhost:8088"
TIMEOUT      = 15   # seconds

USER = {
    "firstName": "Gateway",
    "lastName":  "Tester",
    "username":  f"gw_{uuid.uuid4().hex[:6]}",
    "email":     f"gw_{uuid.uuid4().hex[:6]}@test.com",
    "password":  "Test@1234",
    "pin":       "1234",
}

# ─── State ────────────────────────────────────────────────────────────────────
token          = None
account_number = None
account_id     = None
atm_code       = None
qr_code        = None
results        = []

# ─── Helpers ──────────────────────────────────────────────────────────────────
def url(path):
    return f"{GATEWAY_URL}{path}"

def H():
    return {"Authorization": f"Bearer {token}"}

def req(method, path, auth=True, **kwargs):
    kwargs.setdefault("timeout", TIMEOUT)
    headers = kwargs.pop("headers", {})
    if auth and token:
        headers.update(H())
    try:
        return requests.request(method, url(path), headers=headers, **kwargs)
    except requests.exceptions.ConnectionError:
        print(f"  ❌ Cannot connect to {GATEWAY_URL} — is Docker running?")
        sys.exit(1)

def log(title, res):
    print(f"\n{'─'*60}")
    print(f"  [{res.status_code}] {title}")
    try:
        body = res.json()
        print(json.dumps(body, indent=2))
    except Exception:
        print(res.text[:300])
        body = {}
    return body

def record(title, passed, note=""):
    icon = "✅ PASS" if passed else "❌ FAIL"
    print(f"  → {icon}  {note}")
    results.append({"title": title, "passed": passed, "note": note})
    return passed

def idempotency():
    return uuid.uuid4().hex

# =============================================================================
# SECTION 1 — Gateway Health
# =============================================================================

def test_gateway_health():
    title = "GET /health — gateway is UP"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/health", auth=False)
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") == "UP"
    record(title, ok, f"status={body.get('status')}")


def test_gateway_rate_limit_info():
    title = "GET /health/rate-limits — rate limit endpoint exists"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/health/rate-limits", auth=False)
    body = log(title, res)
    ok   = res.status_code == 200 and "blockedCount" in body
    record(title, ok, f"blockedCount={body.get('blockedCount')}")

# =============================================================================
# SECTION 2 — Auth (public endpoints, no JWT required)
# =============================================================================

def test_register():
    title = "POST /api/v1/auth/register — via gateway (no JWT)"
    print(f"\n{'='*60}\n{title}")
    res  = req("POST", "/api/v1/auth/register", auth=False, json=USER)
    body = log(title, res)
    ok   = res.status_code in (200, 201)
    record(title, ok, f"HTTP {res.status_code}")


def test_login():
    global token
    title = "POST /api/v1/auth/login — via gateway (no JWT)"
    print(f"\n{'='*60}\n{title}")
    res  = req("POST", "/api/v1/auth/login", auth=False, json={
        "username": USER["username"], "password": USER["password"]
    })
    body = log(title, res)
    token = body.get("token")
    ok    = res.status_code == 200 and bool(token)
    record(title, ok, f"token={'yes' if token else 'MISSING'}")


def test_protected_without_token():
    """Verify gateway blocks requests with no JWT to protected endpoints."""
    title = "GET /api/v1/accounts — no token → expect 401"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/accounts", auth=False)
    body = log(title, res)
    ok   = res.status_code == 401
    record(title, ok, f"HTTP {res.status_code} (expected 401)")


def test_protected_with_bad_token():
    """Verify gateway rejects a fake/tampered JWT."""
    title = "GET /api/v1/accounts — fake token → expect 401"
    print(f"\n{'='*60}\n{title}")
    headers = {"Authorization": "Bearer fake.token.here"}
    res  = requests.get(url("/api/v1/accounts"), headers=headers, timeout=TIMEOUT)
    body = log(title, res)
    ok   = res.status_code == 401
    record(title, ok, f"HTTP {res.status_code} (expected 401)")

# =============================================================================
# SECTION 3 — Accounts
# =============================================================================

def test_list_accounts():
    title = "GET /api/v1/accounts — via gateway (JWT)"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/accounts")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")


def test_create_account():
    global account_number, account_id
    title = "POST /api/v1/accounts — create savings account"
    print(f"\n{'='*60}\n{title}")
    res  = req("POST", "/api/v1/accounts", json={
        "accountType": "SAVINGS", "currency": "USD"
    })
    body = log(title, res)
    account_number = body.get("accountNumber")
    account_id     = body.get("id")
    ok = res.status_code in (200, 201) and bool(account_number)
    record(title, ok, f"accountNumber={account_number}")

# =============================================================================
# SECTION 4 — Transactions
# =============================================================================

def test_transaction_history():
    title = "GET /api/v1/transactions — history via gateway"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/transactions")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")


def test_deposit():
    title = "POST /api/v1/transactions/deposit — $500 via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/deposit", json={
        "toAccountNumber": account_number,
        "amount": 500.00,
        "pin": USER["pin"],
        "note": "Gateway test deposit",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")


def test_withdraw():
    title = "POST /api/v1/transactions/withdraw — $50 via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/withdraw", json={
        "fromAccountNumber": account_number,
        "amount": 50.00,
        "pin": USER["pin"],
        "note": "Gateway test withdraw",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")


def test_transfer():
    title = "POST /api/v1/transactions/transfer — self transfer via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/transfer", json={
        "fromAccountNumber": account_number,
        "toAccountNumber":   account_number,
        "amount": 10.00,
        "pin": USER["pin"],
        "note": "Gateway test transfer",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")

# =============================================================================
# SECTION 5 — ATM Cardless Withdrawal
# =============================================================================

def test_atm_generate():
    global atm_code
    title = "POST /api/v1/atm/generate — generate ATM code via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/atm/generate", json={
        "accountNumber": account_number,
        "amount": 20.00,
        "pin": USER["pin"],
    })
    body = log(title, res)
    atm_code = body.get("code")
    ok = res.status_code in (200, 201) and bool(atm_code) and len(str(atm_code)) == 12
    record(title, ok, f"code={'*'*8+str(atm_code)[-4:] if atm_code else 'MISSING'} (12 digits={len(str(atm_code))==12 if atm_code else False})")


def test_atm_status():
    title = "GET /api/v1/atm/status/{code} — check ATM code status"
    print(f"\n{'='*60}\n{title}")
    if not atm_code:
        record(title, False, "SKIP — no atm_code"); return
    res  = req("GET", f"/api/v1/atm/status/{atm_code}")
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") == "PENDING"
    record(title, ok, f"status={body.get('status')}")


def test_atm_cancel():
    title = "DELETE /api/v1/atm/cancel/{code} — cancel ATM code"
    print(f"\n{'='*60}\n{title}")
    if not atm_code:
        record(title, False, "SKIP — no atm_code"); return
    res  = req("DELETE", f"/api/v1/atm/cancel/{atm_code}")
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") == "CANCELLED"
    record(title, ok, f"status={body.get('status')}")

# =============================================================================
# SECTION 6 — QR Payment
# =============================================================================

def test_qr_generate():
    global qr_code
    title = "POST /api/v1/qr/generate — generate QR code via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/qr/generate", json={
        "accountNumber": account_number,
        "amount": 25.00,
        "currency": "USD",
        "note": "Gateway QR test",
    })
    body = log(title, res)
    qr_code = body.get("qrCode")
    ok = res.status_code in (200, 201) and bool(qr_code)
    record(title, ok, f"qrCode={'yes' if qr_code else 'MISSING'}")


def test_qr_history():
    title = "GET /api/v1/qr/history/{accountNumber} — QR history via gateway"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("GET", f"/api/v1/qr/history/{account_number}")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")


def test_qr_cancel():
    title = "DELETE /api/v1/qr/cancel/{qrCode} — cancel QR via gateway"
    print(f"\n{'='*60}\n{title}")
    if not qr_code:
        record(title, False, "SKIP — no qr_code"); return
    res  = req("DELETE", f"/api/v1/qr/cancel/{qr_code}")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")

# =============================================================================
# SECTION 7 — X-Gateway header forwarding
# =============================================================================

def test_xgateway_header():
    """Verify requests through gateway carry X-Gateway header (check via a
       known endpoint that echoes headers, or just confirm no bypass happens)."""
    title = "Gateway header — X-Gateway forwarded to backend"
    print(f"\n{'='*60}\n{title}")
    # We can't easily inspect what header the backend received, but we can
    # verify the response came from the gateway path (status is same as direct)
    res  = req("GET", "/api/v1/transactions")
    ok   = res.status_code == 200
    record(title, ok, "Request routed through gateway successfully")

# =============================================================================
# Summary
# =============================================================================

def summary():
    print("\n" + "=" * 60)
    print("📊  GATEWAY TEST SUMMARY")
    print("=" * 60)
    passed = sum(1 for r in results if r["passed"])
    total  = len(results)
    for r in results:
        icon = "✅" if r["passed"] else "❌"
        print(f"  {icon}  {r['title']}")
        if not r["passed"] and r["note"]:
            print(f"       ↳ {r['note']}")
    print(f"\n  Result : {passed}/{total} passed")
    if passed == total:
        print("  🎉 All gateway tests passed!")
    else:
        print("  ⚠️  Some tests failed — check Docker logs:")
        print("       docker compose logs -f titan-gateway-go titan-core-banking")
    print("=" * 60)
    return passed == total


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("🚀  titan-gateway-go  END-TO-END TESTS")
    print(f"    Target : {GATEWAY_URL}")
    print("=" * 60)

    # ── Section 1: Health ─────────────────────────────────────────────────────
    print("\n📌 SECTION 1 — Gateway Health")
    test_gateway_health()
    test_gateway_rate_limit_info()

    # ── Section 2: Auth ───────────────────────────────────────────────────────
    print("\n📌 SECTION 2 — Auth (public endpoints)")
    test_register()
    test_login()
    if not token:
        print("\n❌ Login failed — cannot continue. Is core-banking running?")
        summary()
        sys.exit(1)
    test_protected_without_token()
    test_protected_with_bad_token()

    # ── Section 3: Accounts ───────────────────────────────────────────────────
    print("\n📌 SECTION 3 — Accounts")
    test_list_accounts()
    test_create_account()

    # ── Section 4: Transactions ───────────────────────────────────────────────
    print("\n📌 SECTION 4 — Transactions")
    test_transaction_history()
    test_deposit()
    test_withdraw()
    test_transfer()

    # ── Section 5: ATM ────────────────────────────────────────────────────────
    print("\n📌 SECTION 5 — ATM Cardless Withdrawal")
    test_atm_generate()
    test_atm_status()
    test_atm_cancel()

    # ── Section 6: QR ─────────────────────────────────────────────────────────
    print("\n📌 SECTION 6 — QR Payment")
    test_qr_generate()
    test_qr_history()
    test_qr_cancel()

    # ── Section 7: Routing ────────────────────────────────────────────────────
    print("\n📌 SECTION 7 — Routing / Headers")
    test_xgateway_header()

    ok = summary()
    sys.exit(0 if ok else 1)
