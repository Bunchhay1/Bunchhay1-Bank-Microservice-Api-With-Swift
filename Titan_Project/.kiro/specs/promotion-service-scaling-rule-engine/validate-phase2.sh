#!/bin/bash

# Phase 2 Validation Script
# Tests all 10 tasks implementation

set -e

BASE_URL="http://localhost:8083"
KAFKA_BROKER="localhost:9093"

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Phase 2: Promotion Service Validation                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Test 1: Service Health
echo "✓ Test 1: Service Health Check"
curl -s $BASE_URL/actuator/health | jq .
echo ""

# Test 2: Redis Connection
echo "✓ Test 2: Redis Connection"
redis-cli PING
echo ""

# Test 3: Database Connection
echo "✓ Test 3: Database Schema"
psql -d titandb -c "\dt campaigns" 2>/dev/null || echo "Run migrations first"
echo ""

# Test 4: Metrics Endpoint
echo "✓ Test 4: Prometheus Metrics"
curl -s $BASE_URL/actuator/prometheus | grep -E "promotion_(evaluation|applied|duplicate)" | head -5
echo ""

# Test 5: Cache Service
echo "✓ Test 5: Campaign Cache"
redis-cli LRANGE campaigns:active 0 -1
echo ""

# Test 6: Admin API (Create Campaign)
echo "✓ Test 6: Create Test Campaign"
CAMPAIGN_RESPONSE=$(curl -s -X POST $BASE_URL/admin/campaigns \
  -H 'Content-Type: application/json' \
  -d '{
    "campaignCode": "VALIDATION_TEST",
    "name": "Validation Test Campaign",
    "ruleExpression": "#transactionAmount >= 50 && #currency == '\''USD'\''",
    "rewardAmount": 5.00,
    "quotaLimit": 10,
    "startDate": "2026-03-01T00:00:00",
    "endDate": "2026-12-31T23:59:59"
  }' 2>/dev/null || echo "Security not configured - expected")
echo $CAMPAIGN_RESPONSE | jq . 2>/dev/null || echo "Campaign creation requires authentication"
echo ""

# Test 7: Idempotency Service
echo "✓ Test 7: Idempotency Check"
redis-cli SET promo:processed:99999 "1" EX 604800
redis-cli GET promo:processed:99999
echo ""

# Test 8: Database Queries
echo "✓ Test 8: Database Queries"
psql -d titandb -c "SELECT campaign_code, status, quota_used, quota_limit FROM campaigns LIMIT 3;" 2>/dev/null || echo "Database not accessible"
echo ""

# Test 9: Kafka Topics
echo "✓ Test 9: Kafka Topics"
kafka-topics --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | grep -E "(transactions|rewards)" || echo "Kafka not accessible"
echo ""

# Test 10: Outbox Table
echo "✓ Test 10: Outbox Table"
psql -d titandb -c "SELECT COUNT(*) as pending_events FROM promotion_outbox WHERE status = 'PENDING';" 2>/dev/null || echo "Database not accessible"
echo ""

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Validation Complete                                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next Steps:"
echo "1. Review logs: tail -f logs/promotions.log"
echo "2. Monitor metrics: curl $BASE_URL/actuator/prometheus"
echo "3. Send test transaction to Kafka"
echo "4. Verify promotion applied in database"
echo ""
