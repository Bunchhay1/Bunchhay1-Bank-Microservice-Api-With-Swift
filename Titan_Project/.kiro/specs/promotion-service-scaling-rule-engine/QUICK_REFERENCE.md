# Phase 2 Quick Reference

## Build & Run

```bash
# Build
cd titan-promotions-service
./gradlew clean build

# Run with Redis
docker run -d -p 6379:6379 redis:7-alpine

# Start service
./gradlew bootRun
```

## Admin API Examples

### Create Campaign
```bash
curl -X POST http://localhost:8083/admin/campaigns \
  -H 'Content-Type: application/json' \
  -d '{
    "campaignCode": "FIRST_1000",
    "name": "First 1000 Users Get $5",
    "ruleExpression": "#transactionAmount >= 50 && #currency == '\''USD'\''",
    "rewardAmount": 5.00,
    "quotaLimit": 1000,
    "startDate": "2026-03-01T00:00:00",
    "endDate": "2026-12-31T23:59:59"
  }'
```

### Pause Campaign
```bash
curl -X PUT http://localhost:8083/admin/campaigns/1/pause
```

### List Campaigns
```bash
curl http://localhost:8083/admin/campaigns
```

## SpEL Rule Examples

```java
// Amount threshold
"#transactionAmount >= 100"

// Currency check
"#currency == 'USD'"

// Transaction type
"#transactionType == 'DEPOSIT'"

// Metadata check
"#metadata['channel'] == 'DIGITAL_BANKING'"

// Complex rule
"#transactionAmount >= 500 && #transactionType == 'DEPOSIT' && #currency == 'USD'"

// Metadata with amount
"#metadata['channel'] == 'MOBILE_APP' && #transactionAmount >= 50"
```

## Redis Commands

```bash
# Check active campaigns cache
redis-cli LRANGE campaigns:active 0 -1

# Check idempotency
redis-cli GET promo:processed:12345

# Clear cache
redis-cli DEL campaigns:active

# Check all promotion keys
redis-cli KEYS promo:*
```

## Database Queries

```sql
-- Active campaigns
SELECT * FROM campaigns WHERE status = 'ACTIVE';

-- Campaign performance
SELECT 
    c.campaign_code,
    c.quota_used,
    c.quota_limit,
    COUNT(ap.id) as total_applied,
    SUM(ap.promotion_amount) as total_rewards
FROM campaigns c
LEFT JOIN applied_promotions ap ON c.id = ap.campaign_id
GROUP BY c.id;

-- Pending outbox events
SELECT * FROM promotion_outbox WHERE status = 'PENDING';

-- Failed rewards
SELECT * FROM applied_promotions WHERE reward_status = 'FAILED';
```

## Metrics Endpoints

```bash
# Prometheus metrics
curl http://localhost:8083/actuator/prometheus

# Health check
curl http://localhost:8083/actuator/health

# All metrics
curl http://localhost:8083/actuator/metrics
```

## Key Metrics

- `promotion.evaluation.time` - Rule evaluation latency
- `promotion.applied.total` - Total promotions applied
- `promotion.duplicate.events` - Duplicate transactions blocked
- `kafka.consumer.lag` - Consumer lag

## Troubleshooting

### Campaign not triggering
1. Check campaign status: `SELECT * FROM campaigns WHERE campaign_code = 'XXX'`
2. Verify dates: `start_date <= NOW() AND end_date >= NOW()`
3. Check quota: `quota_used < quota_limit`
4. Test rule: Use admin API test endpoint
5. Clear cache: `redis-cli DEL campaigns:active`

### High latency
1. Check Redis: `redis-cli PING`
2. Check database connections
3. Monitor metrics: `promotion.evaluation.time`
4. Scale horizontally

### Outbox buildup
1. Check Kafka broker health
2. Verify topic exists: `banking.rewards.granted`
3. Check failed events: `SELECT * FROM promotion_outbox WHERE status = 'FAILED'`
4. Manual retry: `UPDATE promotion_outbox SET status = 'PENDING' WHERE id = X`

## Testing

```bash
# Send test transaction event
kafka-console-producer --bootstrap-server localhost:9093 \
  --topic banking.transactions.completed \
  --property "parse.key=true" \
  --property "key.separator=:"

# Paste this:
tx-123:{"eventId":"evt-123","transactionId":123,"accountId":456,"amount":150.00,"currency":"USD","transactionType":"DEPOSIT","metadata":{"channel":"DIGITAL_BANKING"}}
```

## Performance Targets

| Operation | Target | Typical |
|-----------|--------|---------|
| Cache lookup | <1ms | 0.5ms |
| Rule evaluation | <5ms | 2-3ms |
| Lock acquisition | <10ms | 5-8ms |
| End-to-end | <50ms | 30-40ms |
