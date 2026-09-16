import requests
import json
import uuid
import time

BASE_URL = "https://banking-bunchhay1.onrender.com"
TIMEOUT = 30  # seconds per request

USER = {
    "firstName": "Test",
    "lastName": "User",
    "username": f"tuser_{uuid.uuid4().hex[:6]}",
    "email": f"tuser_{uuid.uuid4().hex[:6]}@example.com",
    "password": "Test@1234",
    "pin": "1234"
}

token = None
account_number = None
account_id = None      # ← actual DB id from account creation
loan_id = None


def req(method, url, **kwargs):
    kwargs.setdefault("timeout", TIMEOUT)
    return requests.request(method, url, **kwargs)


def log(title, res):
    print(f"\n{'='*55}")
    print(f"[{res.status_code}] {title}")
    try:
        print(json.dumps(res.json(), indent=2))
    except Exception:
        ct = res.headers.get("Content-Type", "")
        print(f"  (binary {len(res.content)} bytes)" if "pdf" in ct else res.text[:300])


def H():
    return {"Authorization": f"Bearer {token}"}


def wake_server():
    """Render free tier sleeps — poll until the server is up."""
    print("⏳ Waking server (may take ~30s on Render free tier)...")
    for i in range(6):
        try:
            r = req("GET", f"{BASE_URL}/actuator/health")
            if r.status_code == 200:
                print("✅ Server is up!")
                return
        except Exception:
            pass
        print(f"  retry {i+1}/6...")
        time.sleep(10)
    print("⚠️  Server did not respond — tests may fail.")


# ── Auth ──────────────────────────────────────────────
def test_health():
    log("GET /actuator/health", req("GET", f"{BASE_URL}/actuator/health"))


def test_register():
    log("POST /auth/register", req("POST", f"{BASE_URL}/api/v1/auth/register", json=USER))


def test_login():
    global token
    res = req("POST", f"{BASE_URL}/api/v1/auth/login", json={
        "username": USER["username"], "password": USER["password"]
    })
    log("POST /auth/login", res)
    token = res.json().get("token")


# ── OTP ───────────────────────────────────────────────
def test_otp_generate():
    log("POST /api/auth/otp/generate", req("POST", f"{BASE_URL}/api/auth/otp/generate", headers=H()))


# ── Accounts ──────────────────────────────────────────
def test_accounts():
    global account_number, account_id
    log("GET /accounts", req("GET", f"{BASE_URL}/api/v1/accounts", headers=H()))

    res = req("POST", f"{BASE_URL}/api/v1/accounts", headers=H(), json={
        "accountType": "SAVINGS", "currency": "USD", "initialDeposit": 1000.00
    })
    log("POST /accounts", res)
    data = res.json()
    account_number = data.get("accountNumber")
    account_id = data.get("id")
    print(f"  → accountNumber: {account_number}, id: {account_id}")


# ── Transactions ──────────────────────────────────────
def test_transactions():
    log("GET /transactions", req("GET", f"{BASE_URL}/api/v1/transactions", headers=H()))


def test_deposit():
    log("POST /transactions/deposit", req("POST", 
        f"{BASE_URL}/api/v1/transactions/deposit", headers=H(), json={
            "toAccountNumber": account_number,
            "amount": 500.00,
            "pin": USER["pin"],
            "note": "Test deposit",
            "idempotencyKey": uuid.uuid4().hex
        }
    ))


def test_withdraw():
    log("POST /transactions/withdraw", req("POST", 
        f"{BASE_URL}/api/v1/transactions/withdraw", headers=H(), json={
            "fromAccountNumber": account_number,
            "amount": 100.00,
            "pin": USER["pin"],
            "note": "Test withdrawal",
            "idempotencyKey": uuid.uuid4().hex
        }
    ))


def test_transfer():
    log("POST /transactions/transfer", req("POST", 
        f"{BASE_URL}/api/v1/transactions/transfer", headers=H(), json={
            "fromAccountNumber": account_number,
            "toAccountNumber": account_number,
            "amount": 50.00,
            "pin": USER["pin"],
            "note": "Self transfer",
            "idempotencyKey": uuid.uuid4().hex
        }
    ))


def test_international_transfer():
    log("POST /transactions/international", req("POST", 
        f"{BASE_URL}/api/v1/transactions/international", headers=H(), json={
            "fromAccountNumber": account_number,
            "toAccountNumber": account_number,
            "amount": 200.00,
            "pin": USER["pin"],
            "swiftCode": "BKCAKHPP",
            "iban": "KH02BKCA0123456789",
            "note": "International test",
            "idempotencyKey": uuid.uuid4().hex
        }
    ))


# ── Scheduled Transaction ─────────────────────────────
def test_scheduled_transaction():
    log("POST /scheduled-transactions", req("POST", 
        f"{BASE_URL}/api/v1/scheduled-transactions", headers=H(), json={
            "fromAccountNumber": account_number,
            "toAccountNumber": account_number,
            "amount": 25.00,
            "pin": USER["pin"],
            "note": "Scheduled test",
            "idempotencyKey": uuid.uuid4().hex
        }
    ))


# ── Loans ─────────────────────────────────────────────
def test_loan_apply():
    global loan_id
    if not account_id:
        print("\n[SKIP] POST /loans/apply — no account_id")
        return
    res = req("POST", f"{BASE_URL}/api/v1/loans/apply", headers=H(), json={
        "accountId": account_id,
        "amount": 1000.00,
        "termMonths": 12,
        "interestRate": 0.05
    })
    log("POST /loans/apply", res)
    loan_id = res.json().get("id")
    print(f"  → loan_id: {loan_id}")


def test_loan_approve():
    if not loan_id:
        print("\n[SKIP] PUT /loans/{id}/approve — no loan_id")
        return
    log(f"PUT /loans/{loan_id}/approve",
        req("PUT", f"{BASE_URL}/api/v1/loans/{loan_id}/approve", headers=H()))


# ── Fixed Deposits ────────────────────────────────────
def test_fixed_deposit():
    if not account_id:
        print("\n[SKIP] POST /fixed-deposits/create — no account_id")
        return
    log("POST /fixed-deposits/create", req("POST", 
        f"{BASE_URL}/api/v1/fixed-deposits/create", headers=H(), json={
            "accountId": account_id,
            "amount": 200.00,
            "termMonths": 6
        }
    ))


# ── Statement ─────────────────────────────────────────
def test_statement():
    if not account_id:
        print("\n[SKIP] GET /statements — no account_id")
        return
    res = req("GET", f"{BASE_URL}/api/v1/statements/{account_id}/pdf", headers=H())
    log(f"GET /statements/{account_id}/pdf", res)
    if "pdf" in res.headers.get("Content-Type", ""):
        fname = f"statement_{account_id}.pdf"
        with open(fname, "wb") as f:
            f.write(res.content)
        print(f"  → Saved {fname}")


# ── Users ─────────────────────────────────────────────
def test_users():
    log("GET /users", req("GET", f"{BASE_URL}/api/v1/users", headers=H()))


if __name__ == "__main__":
    wake_server()
    test_health()
    test_register()
    test_login()
    test_otp_generate()
    test_accounts()
    test_transactions()
    test_deposit()
    test_withdraw()
    test_transfer()
    test_international_transfer()
    test_scheduled_transaction()
    test_loan_apply()
    test_loan_approve()
    test_fixed_deposit()
    test_statement()
    test_users()
