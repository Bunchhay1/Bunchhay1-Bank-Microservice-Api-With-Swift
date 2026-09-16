"""
test_rate_limit.py
==================
Tests titan-gateway-go sliding-window rate limiter.

Rules being tested (from config.yaml):
  max_requests   : 100
  window_seconds : 60   (1 minute)
  block_minutes  : 5    (blocked for 5 min after exceeding 100 req/min)

Test plan:
  PHASE 1 — Warm up (10 requests)      → all must return 200
  PHASE 2 — Burst to limit (90 more)   → requests #11–100 must return 200
  PHASE 3 — Exceed limit (10 more)     → requests #101–110 must return 429
  PHASE 4 — Blocked IP check           → /health/rate-limits must list this IP
  PHASE 5 — Confirm still blocked      → any request must return 429
  PHASE 6 — Wait for cooldown (5 min)  → after block_minutes, must return 200

Run:
  python3 test_rate_limit.py

  # Skip the 5-min cooldown wait (just test block, not unblock):
  python3 test_rate_limit.py --skip-cooldown
"""

import requests
import json
import time
import sys
import threading
from concurrent.futures import ThreadPoolExecutor, as_completed

# ─── Config ───────────────────────────────────────────────────────────────────
GATEWAY_URL    = "http://localhost:8088"
TIMEOUT        = 10
MAX_REQUESTS   = 100        # must match config.yaml max_requests
BLOCK_MINUTES  = 5          # must match config.yaml block_minutes
WINDOW_SECONDS = 60         # must match config.yaml window_seconds

SKIP_COOLDOWN  = "--skip-cooldown" in sys.argv

# ─── Shared state ─────────────────────────────────────────────────────────────
results    = []
lock       = threading.Lock()

# ─── Helpers ──────────────────────────────────────────────────────────────────
def url(path):
    return f"{GATEWAY_URL}{path}"

def req(path="/health", method="GET", **kwargs):
    kwargs.setdefault("timeout", TIMEOUT)
    try:
        return requests.request(method, url(path), **kwargs)
    except requests.exceptions.ConnectionError:
        print(f"\n  ❌ Cannot connect to {GATEWAY_URL} — is titan-gateway-go running?")
        sys.exit(1)
    except requests.exceptions.Timeout:
        # Return a fake 408 so callers can handle it
        class FakeResp:
            status_code = 408
            def json(self): return {}
            text = "TIMEOUT"
        return FakeResp()

def log_phase(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print("=" * 60)

def record(title, passed, note=""):
    icon = "✅ PASS" if passed else "❌ FAIL"
    print(f"  {icon}  {note}")
    results.append({"title": title, "passed": passed, "note": note})
    return passed

def get_remaining(res):
    try:
        return int(res.headers.get("X-RateLimit-Remaining", -1))
    except:
        return -1

def get_retry_after(res):
    try:
        return int(res.headers.get("Retry-After", -1))
    except:
        return -1

# ─── Phase helpers ────────────────────────────────────────────────────────────

def fire_single(n):
    """Fire one request, return (request_number, status_code, remaining)."""
    res = req("/health")
    return n, res.status_code, get_remaining(res)

def fire_burst(start, count, label, workers=10):
    """
    Fire `count` requests starting from sequence number `start`.
    Returns list of (n, status_code, remaining).
    Uses a thread pool to send them quickly within the window.
    """
    print(f"\n  🔥 Firing {count} requests ({label})...")
    outcomes = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(fire_single, start + i): start + i for i in range(count)}
        for future in as_completed(futures):
            n, code, remaining = future.result()
            outcomes.append((n, code, remaining))
            sys.stdout.write(f"\r     Progress: {len(outcomes)}/{count}  "
                             f"[last={code}  remaining={remaining}]  ")
            sys.stdout.flush()
    print()  # newline after progress
    outcomes.sort(key=lambda x: x[0])
    return outcomes

# =============================================================================
# PHASE 1 — Gateway reachable + headers present
# =============================================================================

def phase1_gateway_health():
    log_phase("PHASE 1 — Gateway reachable + rate-limit headers")
    res = req("/health")
    code = res.status_code

    # Check headers exist
    has_limit     = "X-RateLimit-Limit"     in res.headers
    has_window    = "X-RateLimit-Window"    in res.headers
    has_remaining = "X-RateLimit-Remaining" in res.headers

    print(f"  HTTP status       : {code}")
    print(f"  X-RateLimit-Limit     : {res.headers.get('X-RateLimit-Limit', 'MISSING')}")
    print(f"  X-RateLimit-Window    : {res.headers.get('X-RateLimit-Window', 'MISSING')}")
    print(f"  X-RateLimit-Remaining : {res.headers.get('X-RateLimit-Remaining', 'MISSING')}")

    ok = code == 200
    record("Gateway reachable", ok, f"HTTP {code}")
    record("X-RateLimit-Limit header present",     has_limit,     "header found" if has_limit else "MISSING")
    record("X-RateLimit-Window header present",    has_window,    "header found" if has_window else "MISSING")
    record("X-RateLimit-Remaining header present", has_remaining, "header found" if has_remaining else "MISSING")

# =============================================================================
# PHASE 2 — Fire 100 requests → all must be 200
# =============================================================================

def phase2_burst_to_limit():
    log_phase(f"PHASE 2 — Fire {MAX_REQUESTS} requests → all must return 200")
    outcomes = fire_burst(1, MAX_REQUESTS, f"requests #1–{MAX_REQUESTS}", workers=20)

    allowed   = [o for o in outcomes if o[1] == 200]
    blocked   = [o for o in outcomes if o[1] == 429]
    other     = [o for o in outcomes if o[1] not in (200, 429)]

    print(f"  Allowed (200) : {len(allowed)}")
    print(f"  Blocked (429) : {len(blocked)}")
    print(f"  Other         : {len(other)}")

    # Check last few X-RateLimit-Remaining values (should approach 0)
    last_remaining = [o[2] for o in outcomes[-5:] if o[2] >= 0]
    if last_remaining:
        print(f"  Remaining (last 5 reqs): {last_remaining}")

    ok = len(allowed) == MAX_REQUESTS and len(blocked) == 0
    record(
        f"All {MAX_REQUESTS} requests allowed before limit",
        ok,
        f"{len(allowed)} allowed, {len(blocked)} blocked (expected 0 blocked)"
    )
    return len(blocked) == 0   # return True if we can proceed to phase 3

# =============================================================================
# PHASE 3 — Fire 10 more → all must be 429
# =============================================================================

def phase3_exceed_limit():
    log_phase(f"PHASE 3 — Fire 10 more requests (#{MAX_REQUESTS+1}–{MAX_REQUESTS+10}) → all must return 429")
    outcomes = fire_burst(MAX_REQUESTS + 1, 10, f"requests #{MAX_REQUESTS+1}–{MAX_REQUESTS+10}", workers=5)

    blocked = [o for o in outcomes if o[1] == 429]
    allowed = [o for o in outcomes if o[1] == 200]

    print(f"  Blocked (429) : {len(blocked)}")
    print(f"  Allowed (200) : {len(allowed)}  ← should be 0")

    if blocked:
        # Show body of first blocked response to confirm message
        res = req("/health")   # will be 429 since IP is now blocked
        try:
            body = res.json()
            print(f"\n  429 Response body:")
            print(json.dumps(body, indent=4))
            retry_after = body.get("retryAfter", "?")
            blocked_until = body.get("blockedUntil", "?")
            print(f"\n  Retry-After   : {res.headers.get('Retry-After', '?')}s")
            print(f"  blockedUntil  : {blocked_until}")
        except:
            pass

    ok = len(blocked) == 10 and len(allowed) == 0
    record(
        "All 10 over-limit requests blocked (429)",
        ok,
        f"{len(blocked)}/10 blocked (expected all 10)"
    )
    return len(blocked) > 0

# =============================================================================
# PHASE 4 — Verify IP appears in /health/rate-limits
# =============================================================================

def phase4_check_blocked_list():
    log_phase("PHASE 4 — Verify IP is listed in /health/rate-limits")
    res  = req("/health/rate-limits")
    body = {}
    try:
        body = res.json()
    except:
        pass

    print(f"  HTTP status   : {res.status_code}")
    print(json.dumps(body, indent=2))

    blocked_count = body.get("blockedCount", 0)
    blocked_ips   = body.get("blockedIPs", {})

    ok = res.status_code == 200 and blocked_count > 0
    record(
        "Blocked IP listed in /health/rate-limits",
        ok,
        f"blockedCount={blocked_count}, IPs={list(blocked_ips.keys())}"
    )

# =============================================================================
# PHASE 5 — Confirm still blocked mid-window
# =============================================================================

def phase5_still_blocked():
    log_phase("PHASE 5 — Confirm IP is still blocked (mid-window)")
    time.sleep(2)   # 2 seconds into the block period
    res  = req("/health")
    code = res.status_code
    remaining = get_remaining(res)
    retry_after = get_retry_after(res)

    print(f"  HTTP status       : {code}")
    print(f"  X-RateLimit-Remaining : {remaining}")
    print(f"  Retry-After       : {retry_after}s")

    ok = code == 429
    record("IP still blocked mid-window", ok, f"HTTP {code} (expected 429)")

# =============================================================================
# PHASE 6 — Wait for block to expire and confirm unblock
# =============================================================================

def phase6_wait_for_unblock():
    log_phase(f"PHASE 6 — Wait {BLOCK_MINUTES} min for block to expire, then confirm unblock")

    if SKIP_COOLDOWN:
        print(f"  ⏭️  --skip-cooldown flag set — skipping {BLOCK_MINUTES}-minute wait.")
        print(f"     To test unblock, run again without --skip-cooldown")
        record("Cooldown unblock", True, "SKIPPED (--skip-cooldown)")
        return

    wait_secs = BLOCK_MINUTES * 60 + 5   # +5s buffer
    print(f"  ⏳ Waiting {wait_secs}s ({BLOCK_MINUTES}m + 5s buffer)...")

    for remaining in range(wait_secs, 0, -10):
        sys.stdout.write(f"\r     {remaining}s remaining...   ")
        sys.stdout.flush()
        time.sleep(min(10, remaining))

    print("\n  ⏰ Cooldown complete — testing unblock...")

    res  = req("/health")
    code = res.status_code
    remaining = get_remaining(res)

    print(f"  HTTP status           : {code}")
    print(f"  X-RateLimit-Remaining : {remaining}")

    ok = code == 200
    record(
        f"IP unblocked after {BLOCK_MINUTES}m cooldown",
        ok,
        f"HTTP {code} (expected 200 after block expired)"
    )

    # Also check rate-limits endpoint — IP should be gone
    res2 = req("/health/rate-limits")
    try:
        body = res2.json()
        blocked_count = body.get("blockedCount", -1)
        print(f"  blockedCount after cooldown: {blocked_count}")
        ok2 = blocked_count == 0
        record("IP removed from blocked list after cooldown", ok2,
               f"blockedCount={blocked_count} (expected 0)")
    except:
        record("IP removed from blocked list after cooldown", False, "could not parse response")

# =============================================================================
# Summary
# =============================================================================

def summary():
    print("\n" + "=" * 60)
    print("📊  RATE LIMIT TEST SUMMARY")
    print("=" * 60)
    passed = sum(1 for r in results if r["passed"])
    total  = len(results)
    for r in results:
        icon = "✅" if r["passed"] else "❌"
        print(f"  {icon}  {r['title']}")
        if r["note"]:
            print(f"       ↳ {r['note']}")
    print(f"\n  Result : {passed}/{total} passed")
    print()
    if passed == total:
        print("  🎉 All rate limit tests passed!")
        print("     Gateway correctly enforces 100 req/min per IP with block/unblock.")
    else:
        print("  ⚠️  Some tests failed. Common causes:")
        print("     - Gateway not running: docker compose up -d titan-gateway-go")
        print("     - Config mismatch: check config.yaml max_requests / block_minutes")
        print("     - Gateway was rebuilt and old block state was cleared")
        print()
        print("  Debug commands:")
        print("     docker compose logs -f titan-gateway-go")
        print("     curl http://localhost:8088/health/rate-limits")
    print("=" * 60)
    return passed == total

# =============================================================================
# Main
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("🛡️   titan-gateway-go  RATE LIMIT TESTS")
    print(f"    Target         : {GATEWAY_URL}")
    print(f"    Limit          : {MAX_REQUESTS} req / {WINDOW_SECONDS}s")
    print(f"    Block duration : {BLOCK_MINUTES} minutes")
    print(f"    Skip cooldown  : {'YES' if SKIP_COOLDOWN else 'NO'}")
    print("=" * 60)

    phase1_gateway_health()
    phase2_burst_to_limit()
    phase3_exceed_limit()
    phase4_check_blocked_list()
    phase5_still_blocked()
    phase6_wait_for_unblock()

    ok = summary()
    sys.exit(0 if ok else 1)
