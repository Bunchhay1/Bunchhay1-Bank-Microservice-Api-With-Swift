"""
test_risk_block.py
==================
Tests for Titan AI Risk Engine — transfer block logic.

Rule being tested:
  Amount < $100,000   → ALLOW / REVIEW  → transaction status = SUCCESS
  Amount >= $100,000  → BLOCK           → transaction status = BLOCKED

Run:
  python3 test_risk_block.py
"""

import requests
import json
import uuid
import time

BASE_URL = "https://banking-bunchhay1.onrender.com"

# Transfer calls may be slow on first run while the gRPC circuit breaker
# times out trying to reach AI service. Use 90s timeout + retry.
TIMEOUT  = 90

USER = {
    "firstName": "Risk",
    "lastName":  "Tester",
    "username":  f"risk_{uuid.uuid4().hex[:6]}",
    "email":     f"risk_{uuid.uuid4().hex[:6]}@test.com",
    "password":  "Test@1234",
    "pin":       "1234"
}

token           = None
account_number  = None
account_number2 = None
account_id      = None
results         = []


# ── Fake response for timeout/error cases ────────────────────────────────────
class FakeResponse:
    def __init__(self, code, msg):
        self.status_code = code
        self._body = {"status": msg, "error": msg}
        self.headers = {}
    def json(self):
        return self._body
    @property
    def text(self):
        return json.dumps(self._body)


# ── Helpers ───────────────────────────────────────────────────────────────────
def req(method, path, retries=3, **kwargs):
    """Makes request with retry on timeout so the test never crashes."""
    kwargs.setdefault("timeout", TIMEOUT)
    url = f"{BASE_URL}{path}"
    for attempt in range(1, retries + 1):
        try:
            return requests.request(method, url, **kwargs)
        except requests.exceptions.Timeout:
            if attempt == retries:
                print(f"  ⚠️  Request timed out after {retries} attempts — "
                      f"circuit breaker may still be warming up.")
                return FakeResponse(504, "TIMEOUT")
            print(f"  ⏳ Timeout (attempt {attempt}/{retries}), retrying in 5s...")
            time.sleep(5)
        except Exception as e:
            print(f"  ❌ Request error: {e}")
            return FakeResponse(0, "ERROR")


def H():
    return {"Authorization": f"Bearer {token}"}


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
    results.append({"title": title, "passed": passed})


def get_status(body):
    return str(
        body.get("status") or
        body.get("transactionStatus") or
        body.get("data", {}).get("status") or
        "UNKNOWN"
    ).upper()


def wake_server():
    print("⏳ Waking server (Render free tier may take ~30s)...")
    for i in range(10):
        try:
            r = requests.get(f"{BASE_URL}/actuator/health", timeout=15)
            if r.status_code == 200:
                print("✅ Server is up!\n")
                return
        except Exception:
            pass
        print(f"   retry {i+1}/10 ...")
        time.sleep(10)
    print("⚠️  Server slow — continuing anyway.\n")


# ── Setup ─────────────────────────────────────────────────────────────────────
def setup():
    global token, account_number, account_number2, account_id

    print("=" * 60)
    print("🔧 SETUP")
    print("=" * 60)

    req("POST", "/api/v1/auth/register", json=USER)

    res = req("POST", "/api/v1/auth/login", json={
        "username": USER["username"], "password": USER["password"]
    })
    token = res.json().get("token")
    assert token, "❌ Login failed — no token returned"
    print(f"✅ Logged in as {USER['username']}")

    res = req("POST", "/api/v1/accounts", headers=H(), json={
        "accountType": "SAVINGS", "currency": "USD", "initialDeposit": 0
    })
    data = res.json()
    account_number = data.get("accountNumber")
    account_id     = data.get("id")
    print(f"✅ Account 1 (source):      {account_number}")

    res = req("POST", "/api/v1/accounts", headers=H(), json={
        "accountType": "SAVINGS", "currency": "USD", "initialDeposit": 0
    })
    account_number2 = res.json().get("accountNumber")
    print(f"✅ Account 2 (destination): {account_number2}")

    res = req("POST", "/api/v1/transactions/deposit", headers=H(), json={
        "toAccountNumber": account_number,
        "amount": 600000.00,
        "pin": USER["pin"],
        "note": "Fund for risk tests",
        "idempotencyKey": uuid.uuid4().hex
    })
    print(f"✅ Deposited $600,000 [{res.status_code}]")

    # Wait for circuit breaker to initialize on first gRPC attempt
    print("⏳ Waiting 3s for circuit breaker to warm up...")
    time.sleep(3)


# ── Transfer helper ───────────────────────────────────────────────────────────
def transfer(amount, label):
    return req("POST", "/api/v1/transactions/transfer", headers=H(), json={
        "fromAccountNumber": account_number,
        "toAccountNumber":   account_number2,
        "amount":            amount,
        "pin":               USER["pin"],
        "note":              label,
        "idempotencyKey":    uuid.uuid4().hex
    })


# ── Tests ─────────────────────────────────────────────────────────────────────
def test_low_risk():
    title = "Transfer $500 (LOW risk) → expect SUCCESS"
    print(f"\n{'='*60}\nTEST 1 — {title}")
    body   = log(title, transfer(500, "low risk"))
    status = get_status(body)
    record(title, status == "SUCCESS", f"status = {status}")


def test_medium_risk():
    title = "Transfer $5,000 (MEDIUM risk) → expect SUCCESS"
    print(f"\n{'='*60}\nTEST 2 — {title}")
    body   = log(title, transfer(5000, "medium risk"))
    status = get_status(body)
    record(title, status == "SUCCESS", f"status = {status}")


def test_high_risk():
    title = "Transfer $50,000 (HIGH risk) → expect SUCCESS"
    print(f"\n{'='*60}\nTEST 3 — {title}")
    body   = log(title, transfer(50000, "high risk"))
    status = get_status(body)
    record(title, status == "SUCCESS", f"status = {status}")


def test_just_under():
    title = "Transfer $99,999.99 (just under limit) → expect SUCCESS"
    print(f"\n{'='*60}\nTEST 4 — {title}")
    body   = log(title, transfer(99999.99, "just under limit"))
    status = get_status(body)
    record(title, status == "SUCCESS", f"status = {status}")


def test_exact_limit():
    title = "Transfer $100,000 (exact limit) → expect BLOCKED 🚫"
    print(f"\n{'='*60}\nTEST 5 — {title}")
    body   = log(title, transfer(100000, "exact limit"))
    status = get_status(body)
    record(title, status == "BLOCKED", f"status = {status}")


def test_over_limit():
    title = "Transfer $200,000 (over limit) → expect BLOCKED 🚫"
    print(f"\n{'='*60}\nTEST 6 — {title}")
    body   = log(title, transfer(200000, "over limit"))
    status = get_status(body)
    record(title, status == "BLOCKED", f"status = {status}")


def test_extreme():
    title = "Transfer $1,000,000 (extreme) → expect BLOCKED 🚫"
    print(f"\n{'='*60}\nTEST 7 — {title}")
    body   = log(title, transfer(1000000, "extreme amount"))
    status = get_status(body)
    record(title, status == "BLOCKED", f"status = {status}")


def test_balance_unchanged():
    """
    Blocked transfers must NOT deduct from account balance.
    Allowed transfers: $500 + $5,000 + $50,000 + $99,999.99 = $155,499.99
    Starting balance: $600,000
    Expected balance: ~$444,500 (minus any small fees)
    Blocked ($100k + $200k + $1M) must NOT be in the deduction.
    """
    title = "Balance unchanged after blocked transfers"
    print(f"\n{'='*60}\nTEST 8 — {title}")
    body = log(title, req("GET", "/api/v1/accounts", headers=H()))

    accounts = body if isinstance(body, list) else body.get("data", [])
    balance  = None
    for acc in accounts:
        if acc.get("accountNumber") == account_number:
            balance = float(acc.get("balance", 0))
            break

    if balance is None:
        record(title, False, "could not read balance")
        return

    # If blocks leaked, balance would be ~-$756,500 (not possible) or
    # around $143,500 (if $100k+$200k deducted) or $-856,500 (if all deducted).
    # Safe threshold: balance must be > $400,000
    passed = balance >= 400000
    print(f"  → Source account balance : ${balance:,.2f}")
    print(f"  → Expected               : >= $400,000")
    print(f"  → Blocked amounts ($100k + $200k + $1M) should NOT be deducted")
    record(title, passed, f"balance = ${balance:,.2f}")


# ── Summary ───────────────────────────────────────────────────────────────────
def summary():
    print("\n" + "=" * 60)
    print("📊 TEST SUMMARY")
    print("=" * 60)
    passed_count = sum(1 for r in results if r["passed"])
    total        = len(results)
    for r in results:
        print(f"  {'✅' if r['passed'] else '❌'}  {r['title']}")
    print(f"\n  Result: {passed_count}/{total} passed")

    if passed_count == total:
        print("  🎉 All tests passed! Block limit is working correctly.")
    else:
        print()
        if any(not r["passed"] and "BLOCKED" in r["title"] for r in results):
            print("  ⚠️  Block tests failed (status=SUCCESS instead of BLOCKED).")
            print()
            print("  Most likely cause: titan-core-banking has NOT been redeployed")
            print("  yet after the fallback-block fix was pushed.")
            print()
            print("  Fix:")
            print("  1. Go to Render → titan-core-banking → Manual Deploy")
            print("  2. Wait for deploy to finish (~3 min)")
            print("  3. Run this test again")
        if any(not r["passed"] and "TIMEOUT" in r["title"] for r in results):
            print("  ⚠️  Timeout errors: increase TIMEOUT value or wait for")
            print("     Render to fully wake up and try again.")
    print("=" * 60)


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    wake_server()
    setup()

    test_low_risk()
    test_medium_risk()
    test_high_risk()
    test_just_under()
    test_exact_limit()
    test_over_limit()
    test_extreme()
    test_balance_unchanged()

    summary()
