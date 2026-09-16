"""
test_direct_core_banking.py
============================
Same API tests as test_gateway.py but hitting titan-core-banking DIRECTLY
on port 8080, bypassing titan-gateway-go entirely.

Purpose:
  - Verify core-banking is healthy independently of the gateway
  - Confirm the gateway IS needed for security (direct access is possible
    inside Docker but the iOS app must NOT use it directly)

Architecture tested here:
  Test Client
      └─► titan-core-banking  :8080   ← DIRECT (no gateway)

In production the gateway should be the ONLY publicly exposed port.
Port 8080 should NOT be reachable from outside the Docker network.

Run:
  python3 test_direct_core_banking.py
"""

import requests
import json
import uuid
import time
import sys

# ─── Config ───────────────────────────────────────────────────────────────────
CORE_URL = "http://localhost:8080"
TIMEOUT  = 15

USER = {
    "firstName": "Direct",
    "lastName":  "Tester",
    "username":  f"direct_{uuid.uuid4().hex[:6]}",
    "email":     f"direct_{uuid.uuid4().hex[:6]}@test.com",
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
    return f"{CORE_URL}{path}"

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
        print(f"  ❌ Cannot connect to {CORE_URL} — is Docker running?")
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
# SECTION 1 — Core Banking Health (direct)
# =============================================================================

def test_core_health():
    title = "GET /actuator/health — core-banking is UP (direct)"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/actuator/health", auth=False)
    body = log(title, res)
    status = body.get("status", "")
    ok   = res.status_code == 200 and status == "UP"
    record(title, ok, f"status={status}")

# =============================================================================
# SECTION 2 — Auth (direct to core-banking)
# =============================================================================

def test_register():
    title = "POST /api/v1/auth/register — direct to core-banking"
    print(f"\n{'='*60}\n{title}")
    res  = req("POST", "/api/v1/auth/register", auth=False, json=USER)
    body = log(title, res)
    ok   = res.status_code in (200, 201)
    record(title, ok, f"HTTP {res.status_code}")


def test_login():
    global token
    title = "POST /api/v1/auth/login — direct to core-banking"
    print(f"\n{'='*60}\n{title}")
    res  = req("POST", "/api/v1/auth/login", auth=False, json={
        "username": USER["username"], "password": USER["password"]
    })
    body = log(title, res)
    token = body.get("token")
    ok    = res.status_code == 200 and bool(token)
    record(title, ok, f"token={'yes' if token else 'MISSING'}")


def test_no_token_direct():
    """Direct call without token — Spring Security should return 401."""
    title = "GET /api/v1/accounts — no token, direct → expect 401"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/accounts", auth=False)
    body = log(title, res)
    ok   = res.status_code == 401
    record(title, ok, f"HTTP {res.status_code} (expected 401)")

# =============================================================================
# SECTION 3 — Accounts (direct)
# =============================================================================

def test_list_accounts():
    title = "GET /api/v1/accounts — direct with JWT"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/accounts")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")


def test_create_account():
    global account_number, account_id
    title = "POST /api/v1/accounts — direct, create savings"
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
# SECTION 4 — Transactions (direct)
# =============================================================================

def test_transaction_history():
    title = "GET /api/v1/transactions — direct"
    print(f"\n{'='*60}\n{title}")
    res  = req("GET", "/api/v1/transactions")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")


def test_deposit():
    title = "POST /api/v1/transactions/deposit — $500 direct"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/deposit", json={
        "toAccountNumber": account_number,
        "amount": 500.00,
        "pin": USER["pin"],
        "note": "Direct test deposit",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")


def test_withdraw():
    title = "POST /api/v1/transactions/withdraw — $50 direct"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/withdraw", json={
        "fromAccountNumber": account_number,
        "amount": 50.00,
        "pin": USER["pin"],
        "note": "Direct test withdraw",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")


def test_transfer():
    title = "POST /api/v1/transactions/transfer — direct self transfer"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/transactions/transfer", json={
        "fromAccountNumber": account_number,
        "toAccountNumber":   account_number,
        "amount": 10.00,
        "pin": USER["pin"],
        "note": "Direct test transfer",
        "idempotencyKey": idempotency(),
    })
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") in ("SUCCESS", "COMPLETED")
    record(title, ok, f"status={body.get('status')}")

# =============================================================================
# SECTION 5 — ATM (direct)
# =============================================================================

def test_atm_generate():
    global atm_code
    title = "POST /api/v1/atm/generate — direct"
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
    record(title, ok, f"code={'***'+str(atm_code)[-4:] if atm_code else 'MISSING'}")


def test_atm_status():
    title = "GET /api/v1/atm/status/{code} — direct"
    print(f"\n{'='*60}\n{title}")
    if not atm_code:
        record(title, False, "SKIP — no atm_code"); return
    res  = req("GET", f"/api/v1/atm/status/{atm_code}")
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") == "PENDING"
    record(title, ok, f"status={body.get('status')}")


def test_atm_cancel():
    title = "DELETE /api/v1/atm/cancel/{code} — direct"
    print(f"\n{'='*60}\n{title}")
    if not atm_code:
        record(title, False, "SKIP — no atm_code"); return
    res  = req("DELETE", f"/api/v1/atm/cancel/{atm_code}")
    body = log(title, res)
    ok   = res.status_code == 200 and body.get("status") == "CANCELLED"
    record(title, ok, f"status={body.get('status')}")

# =============================================================================
# SECTION 6 — QR (direct)
# =============================================================================

def test_qr_generate():
    global qr_code
    title = "POST /api/v1/qr/generate — direct"
    print(f"\n{'='*60}\n{title}")
    if not account_number:
        record(title, False, "SKIP — no account_number"); return
    res  = req("POST", "/api/v1/qr/generate", json={
        "accountNumber": account_number,
        "amount": 25.00,
        "currency": "USD",
        "note": "Direct QR test",
    })
    body = log(title, res)
    qr_code = body.get("qrCode")
    ok = res.status_code in (200, 201) and bool(qr_code)
    record(title, ok, f"qrCode={'yes' if qr_code else 'MISSING'}")


def test_qr_cancel():
    title = "DELETE /api/v1/qr/cancel/{qrCode} — direct"
    print(f"\n{'='*60}\n{title}")
    if not qr_code:
        record(title, False, "SKIP — no qr_code"); return
    res  = req("DELETE", f"/api/v1/qr/cancel/{qr_code}")
    body = log(title, res)
    ok   = res.status_code == 200
    record(title, ok, f"HTTP {res.status_code}")

# =============================================================================
# Summary
# =============================================================================

def summary():
    print("\n" + "=" * 60)
    print("📊  DIRECT CORE-BANKING TEST SUMMARY")
    print("=" * 60)
    passed = sum(1 for r in results if r["passed"])
    total  = len(results)
    for r in results:
        icon = "✅" if r["passed"] else "❌"
        print(f"  {icon}  {r['title']}")
        if not r["passed"] and r["note"]:
            print(f"       ↳ {r['note']}")
    print(f"\n  Result : {passed}/{total} passed")
    print()
    print("  ⚠️  REMINDER: Port 8080 must NOT be publicly accessible.")
    print("     In production, only port 8088 (gateway) should be exposed.")
    if passed == total:
        print("  ✅ Core-banking is healthy when accessed directly.")
    print("=" * 60)
    return passed == total


# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("🔧  titan-core-banking  DIRECT TESTS  (bypass gateway)")
    print(f"    Target : {CORE_URL}")
    print("=" * 60)

    print("\n📌 SECTION 1 — Core Health")
    test_core_health()

    print("\n📌 SECTION 2 — Auth (direct)")
    test_register()
    test_login()
    if not token:
        print("\n❌ Login failed — cannot continue. Is core-banking running?")
        summary()
        sys.exit(1)
    test_no_token_direct()

    print("\n📌 SECTION 3 — Accounts (direct)")
    test_list_accounts()
    test_create_account()

    print("\n📌 SECTION 4 — Transactions (direct)")
    test_transaction_history()
    test_deposit()
    test_withdraw()
    test_transfer()

    print("\n📌 SECTION 5 — ATM (direct)")
    test_atm_generate()
    test_atm_status()
    test_atm_cancel()

    print("\n📌 SECTION 6 — QR (direct)")
    test_qr_generate()
    test_qr_cancel()

    ok = summary()
    sys.exit(0 if ok else 1)
