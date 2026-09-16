# Phase 2 Deployment Checklist

## Pre-Deployment (Before 7 PM)

### Infrastructure
- [ ] Redis cluster running on port 6379
- [ ] PostgreSQL accessible with `titandb` database
- [ ] Kafka cluster with topics:
  - [ ] `banking.transactions.completed`
  - [ ] `banking.transactions.dlq`
  - [ ] `banking.rewards.granted`
  - [ ] `banking.rewards.acknowledgment`

### Environment Variables
```bash
export REDIS_HOST=localhost
export REDIS_PORT=6379
export DATABASE_URL=jdbc:postgresql://localhost:5432/titandb
export DATABASE_USERNAME=postgres
export DATABASE_PASSWORD=mysecretpassword
export SPRING_KAFKA_BOOTSTRAPSERVERS=localhost:9093
```

### Dependencies Check
```bash
cd titan-promotions-service
./gradlew dependencies | grep -E "(redis|redisson|flyway|security)"
```

## Deployment Steps (7 PM - 8 PM)

### Step 1: Build (5 min)
```bash
cd /Users/chhay/Documents/titan-project/titan-promotions-service
./gradlew clean build -x test
```
**Expected**: BUILD SUCCESSFUL in ~2 minutes

### Step 2: Database Migration (2 min)
```bash
./gradlew flywayMigrate
```
**Expected**: 2 migrations applied (V1, V2)

**Verify**:
```sql
SELECT * FROM flyway_schema_history;
SELECT COUNT(*) FROM campaigns; -- Should be 3 sample campaigns
```

### Step 3: Start Service (1 min)
```bash
./gradlew bootRun
```
**Expected**: 
```
Started PromotionsServiceApplication in X seconds
```

### Step 4: Health Check (1 min)
```bash
curl http://localhost:8083/actuator/health
```
**Expected**:
```json
{
  "status": "UP",
  "components": {
    "db": {"status": "UP"},
    "redis": {"status": "UP"},
    "kafka": {"status": "UP"}
  }
}
```

## Functional Testing (8 PM - 9 PM)

### Test 1: Cache Warming
```bash
# Check Redis
redis-cli LRANGE campaigns:active 0 -1
```
**Expected**: 3 campaigns in cache

### Test 2: Admin API - Create Campaign
```bash
curl -X POST http://localhost:8083/admin/campaigns \
  -H 'Content-Type: application/json' \
  -d '{
    "campaignCode": "DEPLOY_TEST",
    "name": "Deployment Test Campaign",
    "ruleExpression": "#transactionAmount >= 100",
    "rewardAmount": 10.00,
    "quotaLimit": 10,
    "startDate": "2026-03-08T00:00:00",
    "endDate": "2026-12-31T23:59:59"
  }'
```
**Expected**: HTTP 200 with campaign JSON

### Test 3: Idempotency Check
```bash
redis-cli SET promo:processed:99999 "1" EX 604800
redis-cli GET promo:processed:99999
```
**Expected**: "1"

### Test 4: Transaction Processing
```bash
# Produce test transaction
kafka-console-producer --bootstrap-server localhost:9093 \
  --topic banking.transactions.completed \
  --property "parse.key=true" \
  --property "key.separator=:"

# Paste:
tx-test-1:{"eventId":"evt-test-1","transactionId":88888,"accountId":12345,"amount":150.00,"currency":"USD","transactionType":"DEPOSIT","metadata":{"channel":"DIGITAL_BANKING"}}
```

**Verify in DB**:
```sql
SELECT * FROM applied_promotions WHERE transaction_id = 88888;
SELECT * FROM promotion_outbox WHERE status = 'PENDING';
```
**Expected**: 1 row in each table

### Test 5: Outbox Processing
Wait 10 seconds, then:
```sql
SELECT * FROM promotion_outbox WHERE event_id = (
  SELECT reward_event_id FROM applied_promotions WHERE transaction_id = 88888
);
```
**Expected**: `status = 'SENT'`

### Test 6: Distributed Lock
```bash
# Run concurrent requests
for i in {1..10}; do
  curl -X POST http://localhost:8083/test/campaign/1 &
done
wait
```
**Verify**:
```sql
SELECT quota_used FROM campaigns WHERE id = 1;
```
**Expected**: Quota incremented correctly (no race condition)

### Test 7: DLQ Routing
```bash
# Send malformed message
kafka-console-producer --bootstrap-server localhost:9093 \
  --topic banking.transactions.completed

# Paste:
{invalid json}
```

**Verify DLQ**:
```bash
kafka-console-consumer --bootstrap-server localhost:9093 \
  --topic banking.transactions.dlq \
  --from-beginning \
  --max-messages 1
```
**Expected**: Malformed message in DLQ

## Performance Testing (9 PM - 10 PM)

### Test 8: Cache Performance
```bash
# Benchmark cache lookup
redis-cli --latency-history -i 1
```
**Expected**: <1ms average latency

### Test 9: Rule Evaluation Performance
```bash
# Send 1000 transactions
for i in {1..1000}; do
  kafka-console-producer --bootstrap-server localhost:9093 \
    --topic banking.transactions.completed <<< \
    "tx-$i:{\"eventId\":\"evt-$i\",\"transactionId\":$i,\"accountId\":123,\"amount\":150.00,\"currency\":\"USD\",\"transactionType\":\"DEPOSIT\"}"
done
```

**Check metrics**:
```bash
curl -s http://localhost:8083/actuator/prometheus | grep promotion_evaluation_time
```
**Expected**: P95 < 5ms

### Test 10: Throughput Test
```bash
# Use k6 or similar
k6 run --vus 50 --duration 30s load-test.js
```
**Expected**: >10,000 requests/sec

## Monitoring Setup (10 PM - 11 PM)

### Prometheus Configuration
Add to `prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'promotions-service'
    static_configs:
      - targets: ['localhost:8083']
    metrics_path: '/actuator/prometheus'
```

### Grafana Dashboard
Import dashboard with panels:
1. Evaluation Latency (P50, P95, P99)
2. Promotions Applied Rate
3. Duplicate Events Rate
4. Cache Hit Rate
5. Outbox Queue Depth
6. Consumer Lag

### Alert Rules
```yaml
groups:
  - name: promotions
    rules:
      - alert: HighEvaluationLatency
        expr: histogram_quantile(0.95, rate(promotion_evaluation_time_seconds_bucket[5m])) > 0.05
        for: 5m
        
      - alert: OutboxBacklog
        expr: count(promotion_outbox{status="PENDING"}) > 1000
        for: 10m
        
      - alert: HighDuplicateRate
        expr: rate(promotion_duplicate_events[5m]) > 10
        for: 5m
```

## Operational Validation (11 PM - 12 AM)

### Scenario 1: Service Restart
```bash
# Stop service
pkill -f promotions-service

# Verify outbox survives
psql -d titandb -c "SELECT COUNT(*) FROM promotion_outbox WHERE status = 'PENDING';"

# Restart
./gradlew bootRun

# Verify processing resumes
```

### Scenario 2: Redis Failure
```bash
# Stop Redis
docker stop redis

# Send transaction (should fallback to DB)
# Verify service still processes

# Restart Redis
docker start redis

# Verify cache rebuilds
```

### Scenario 3: Campaign Expiry
```bash
# Set campaign end date to past
psql -d titandb -c "UPDATE campaigns SET end_date = NOW() - INTERVAL '1 day' WHERE id = 1;"

# Trigger manual sweep
curl -X POST http://localhost:8083/admin/campaigns/sweep

# Verify status changed to COMPLETED
psql -d titandb -c "SELECT status FROM campaigns WHERE id = 1;"
```

### Scenario 4: Quota Exhaustion
```bash
# Set quota to current usage
psql -d titandb -c "UPDATE campaigns SET quota_limit = quota_used WHERE id = 1;"

# Send transaction
# Verify promotion NOT applied (quota exhausted)
```

## Post-Deployment Verification

### Checklist
- [ ] All 10 functional tests passed
- [ ] Performance benchmarks met
- [ ] Monitoring dashboards showing data
- [ ] Alerts configured and tested
- [ ] Operational scenarios validated
- [ ] Documentation reviewed
- [ ] Team notified of deployment

### Rollback Plan
If issues occur:
```bash
# Stop service
pkill -f promotions-service

# Revert database
./gradlew flywayUndo -Pflyway.target=1

# Deploy previous version
git checkout previous-version
./gradlew bootRun
```

## Success Metrics (Next Day)

Monitor for 24 hours:
- [ ] Zero errors in logs
- [ ] P95 latency < 50ms
- [ ] No DLQ buildup
- [ ] Cache hit rate > 95%
- [ ] Zero duplicate rewards
- [ ] Outbox queue depth < 100

## Sign-Off

- [ ] Developer: _______________  Date: _______
- [ ] QA: _______________  Date: _______
- [ ] Ops: _______________  Date: _______

---

**Deployment Window**: 7 PM - 12 AM (5 hours)
**Estimated Completion**: 11 PM (4 hours)
**Buffer**: 1 hour for issues

**Ready to execute!** 🚀
