# Campaign Rule Expression Guide

## SpEL Variables Available

| Variable | Type | Description | Example |
|----------|------|-------------|---------|
| `#transactionAmount` | BigDecimal | Transaction amount | `150.00` |
| `#currency` | String | Currency code | `"USD"` |
| `#transactionType` | String | Transaction type | `"DEPOSIT"` |
| `#accountId` | Long | Account ID | `12345` |
| `#metadata` | Map | Custom metadata | `{"channel": "MOBILE"}` |

## Rule Expression Examples

### Basic Rules

```java
// Amount threshold
"#transactionAmount >= 100"

// Currency check
"#currency == 'USD'"

// Transaction type
"#transactionType == 'DEPOSIT'"

// Account targeting
"#accountId == 12345"
```

### Combined Rules

```java
// High-value USD deposits
"#transactionAmount >= 500 && #currency == 'USD' && #transactionType == 'DEPOSIT'"

// Digital banking bonus
"#transactionAmount >= 100 && #metadata['channel'] == 'DIGITAL_BANKING'"

// Mobile app exclusive
"#transactionAmount >= 50 && #metadata['channel'] == 'MOBILE_APP' && #currency == 'USD'"

// Weekend bonus
"#transactionAmount >= 200 && #metadata['dayOfWeek'] == 'SATURDAY'"
```

### Advanced Rules

```java
// Tiered rewards
"#transactionAmount >= 1000 ? 100 : (#transactionAmount >= 500 ? 50 : 10)"

// Multiple currencies
"(#currency == 'USD' || #currency == 'EUR') && #transactionAmount >= 100"

// Exclude specific accounts
"#transactionAmount >= 100 && #accountId != 99999"

// VIP customers
"#metadata['customerTier'] == 'VIP' && #transactionAmount >= 50"
```

## Sample Campaigns

### Campaign 1: First 1000 Users
```json
{
  "campaignCode": "FIRST_1000",
  "name": "First 1000 Users Get $5",
  "ruleExpression": "#transactionAmount >= 50 && #currency == 'USD'",
  "rewardAmount": 5.00,
  "quotaLimit": 1000,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-12-31T23:59:59"
}
```

### Campaign 2: High-Value Cashback
```json
{
  "campaignCode": "HIGH_VALUE_CASHBACK",
  "name": "10% Cashback on $500+ Deposits",
  "ruleExpression": "#transactionAmount >= 500 && #transactionType == 'DEPOSIT'",
  "rewardAmount": 50.00,
  "quotaLimit": null,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-06-30T23:59:59"
}
```

### Campaign 3: Digital Banking Exclusive
```json
{
  "campaignCode": "DIGITAL_EXCLUSIVE",
  "name": "Digital Banking $10 Bonus",
  "ruleExpression": "#metadata['channel'] == 'DIGITAL_BANKING' && #transactionAmount >= 100",
  "rewardAmount": 10.00,
  "quotaLimit": 5000,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-12-31T23:59:59"
}
```

### Campaign 4: Black Friday
```json
{
  "campaignCode": "BLACK_FRIDAY_2026",
  "name": "Black Friday 20% Cashback",
  "ruleExpression": "#transactionAmount >= 100 && #transactionType == 'PURCHASE'",
  "rewardAmount": 20.00,
  "quotaLimit": 10000,
  "startDate": "2026-11-27T00:00:00",
  "endDate": "2026-11-28T23:59:59"
}
```

### Campaign 5: Weekend Warrior
```json
{
  "campaignCode": "WEEKEND_WARRIOR",
  "name": "Weekend Deposit Bonus",
  "ruleExpression": "#transactionAmount >= 200 && (#metadata['dayOfWeek'] == 'SATURDAY' || #metadata['dayOfWeek'] == 'SUNDAY')",
  "rewardAmount": 15.00,
  "quotaLimit": null,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-12-31T23:59:59"
}
```

### Campaign 6: New Customer Welcome
```json
{
  "campaignCode": "NEW_CUSTOMER_WELCOME",
  "name": "New Customer $25 Welcome Bonus",
  "ruleExpression": "#metadata['isNewCustomer'] == true && #transactionAmount >= 50",
  "rewardAmount": 25.00,
  "quotaLimit": null,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-12-31T23:59:59"
}
```

### Campaign 7: VIP Tier
```json
{
  "campaignCode": "VIP_EXCLUSIVE",
  "name": "VIP 5% Cashback",
  "ruleExpression": "#metadata['customerTier'] == 'VIP' && #transactionAmount >= 100",
  "rewardAmount": 5.00,
  "quotaLimit": null,
  "startDate": "2026-03-01T00:00:00",
  "endDate": "2026-12-31T23:59:59"
}
```

## Rule Testing

### Test Rule Locally
```bash
curl -X POST http://localhost:8083/admin/campaigns/test-rule \
  -H 'Content-Type: application/json' \
  -d '{
    "ruleExpression": "#transactionAmount >= 100 && #currency == '\''USD'\''",
    "testEvent": {
      "transactionAmount": 150.00,
      "currency": "USD",
      "transactionType": "DEPOSIT"
    }
  }'
```

### Common Mistakes

❌ **Wrong**: `transactionAmount >= 100` (missing #)
✅ **Correct**: `#transactionAmount >= 100`

❌ **Wrong**: `#currency == USD` (missing quotes)
✅ **Correct**: `#currency == 'USD'`

❌ **Wrong**: `#metadata.channel == 'MOBILE'` (dot notation)
✅ **Correct**: `#metadata['channel'] == 'MOBILE'`

## Performance Considerations

### Simple Rules (Fast)
```java
"#transactionAmount >= 100"  // ~1ms
"#currency == 'USD'"          // ~1ms
```

### Complex Rules (Slower)
```java
"#transactionAmount >= 100 && #currency == 'USD' && #metadata['channel'] == 'DIGITAL' && #metadata['tier'] == 'VIP'"  // ~3-5ms
```

### Avoid
```java
// Don't use regex (slow)
"#currency matches '[A-Z]{3}'"

// Don't use method calls
"#transactionAmount.toString().length() > 5"
```

## Metadata Schema

Ensure transaction events include:
```json
{
  "metadata": {
    "channel": "DIGITAL_BANKING",
    "customerTier": "VIP",
    "isNewCustomer": false,
    "dayOfWeek": "MONDAY",
    "deviceType": "MOBILE",
    "location": "US"
  }
}
```

## Campaign Lifecycle

```
CREATE → ACTIVE → PAUSED → ACTIVE → COMPLETED
                     ↓
                  REVOKED
```

### Status Transitions
- **ACTIVE**: Evaluating transactions
- **PAUSED**: Temporarily disabled (can resume)
- **COMPLETED**: Expired (end_date passed)
- **REVOKED**: Permanently disabled

## Best Practices

1. **Start Simple**: Test with basic rules first
2. **Use Metadata**: Leverage metadata for complex targeting
3. **Set Quotas**: Always set quotas for high-value campaigns
4. **Monitor Performance**: Watch evaluation time metrics
5. **Test Rules**: Use test endpoint before deploying
6. **Cache Invalidation**: Admin API auto-invalidates cache
7. **Expiry Dates**: Set realistic end dates
8. **Audit Trail**: All changes logged

## Troubleshooting

### Rule Not Matching
1. Check rule syntax
2. Verify metadata fields exist
3. Test with sample event
4. Check campaign status and dates
5. Verify quota not exhausted

### Performance Issues
1. Simplify complex rules
2. Check Redis cache hit rate
3. Monitor evaluation time metrics
4. Consider rule optimization

### Quota Issues
1. Check quota_used vs quota_limit
2. Verify distributed lock working
3. Monitor for race conditions
4. Check database transaction isolation
