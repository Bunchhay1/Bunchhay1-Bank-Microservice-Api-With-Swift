# Requirements Document

## Introduction

The Titan Banking System requires transformation of the basic titan-promotions-service into an enterprise-grade, high-performance promotion engine capable of handling Black Friday-scale traffic (10,000+ TPS) with dynamic rules, distributed processing, and strict consistency guarantees. The system must support dynamic rule configuration, sub-millisecond evaluation latency, zero data loss, and prevent duplicate reward distribution across 50+ distributed service instances.

## Glossary

- **Promotion_Engine**: The core service responsible for evaluating transactions against promotion rules and dispatching rewards
- **Rule_Engine**: The component that evaluates dynamic promotion rules using Spring Expression Language (SpEL)
- **Campaign**: A promotion configuration with rules, quotas, and validity periods
- **Active_Campaign**: A campaign currently eligible for evaluation (status = ACTIVE, within validity period)
- **Applied_Promotion**: A record of a promotion successfully applied to a transaction
- **Idempotency_Key**: A unique identifier preventing duplicate processing of the same transaction
- **Distributed_Lock**: A coordination mechanism ensuring atomic operations across multiple service instances
- **Outbox_Pattern**: A technique ensuring atomic database writes and event publishing
- **DLQ**: Dead Letter Queue for failed messages requiring manual intervention
- **Consumer_Lag**: The number of unprocessed messages in a Kafka partition
- **Quota_Limit**: Maximum number of times a campaign can be applied (e.g., "First 1000 users")
- **Bank_Admin**: User with privileges to create and manage promotion campaigns
- **End_User**: Customer receiving promotions on qualifying transactions
- **DevOps_Engineer**: User monitoring system health and performance metrics
- **Compliance_Officer**: User auditing promotion application history
- **Transaction_Event**: Kafka message representing a completed banking transaction
- **Reward_Event**: Kafka message triggering account crediting in titan-core-banking
- **Admin_API**: gRPC/REST endpoints for campaign management operations
- **Cache_Invalidation**: Process of removing stale campaign data from Redis
- **Expiry_Sweeper**: Scheduled job moving expired campaigns from ACTIVE to COMPLETED status
- **Virtual_Threads**: Java 21 lightweight threads for high-concurrency operations
- **P99_Latency**: 99th percentile response time metric
- **Redisson**: Redis-based distributed lock implementation library
- **SpEL**: Spring Expression Language for dynamic rule evaluation
- **RBAC**: Role-Based Access Control for admin API authorization
- **CDC**: Change Data Capture for outbox pattern implementation
- **TPS**: Transactions Per Second throughput metric

## Requirements

### Requirement 1: Dynamic Rule Engine

**User Story:** As a Bank Admin, I want to configure promotion rules using expressions without code deployment, so that I can respond quickly to market conditions and launch campaigns in minutes instead of weeks.

#### Acceptance Criteria

1. THE Rule_Engine SHALL evaluate promotion rules using Spring Expression Language (SpEL)
2. WHEN a Bank_Admin creates a Campaign, THE Promotion_Engine SHALL store the rule expression in PostgreSQL
3. THE Rule_Engine SHALL support expressions containing transaction attributes (transactionAmount, currency, merchantCategory, userId)
4. WHEN evaluating a Transaction_Event, THE Rule_Engine SHALL execute the SpEL expression against transaction data
5. IF a rule expression contains syntax errors, THEN THE Admin_API SHALL return a validation error with specific details
6. THE Promotion_Engine SHALL remove all static promotion logic from PromotionRuleProperties
7. WHEN a rule evaluation completes, THE Rule_Engine SHALL log the evaluation result and execution time
8. THE Rule_Engine SHALL support comparison operators (>=, <=, ==, !=) and logical operators (&&, ||, !)
9. THE Rule_Engine SHALL support string operations (contains, startsWith, endsWith, matches)
10. WHEN a Campaign is created with rule `transactionAmount >= 50 && currency == 'USD'`, THE Rule_Engine SHALL correctly identify qualifying transactions

### Requirement 2: Redis Caching Layer

**User Story:** As a DevOps Engineer, I want active campaigns cached in Redis, so that rule evaluation achieves sub-millisecond latency without database queries in the hot path.

#### Acceptance Criteria

1. WHEN a Campaign status changes to ACTIVE, THE Promotion_Engine SHALL store the campaign in Redis with key pattern `campaign:active:{campaignId}`
2. THE Promotion_Engine SHALL cache all Active_Campaigns in Redis on service startup
3. WHEN evaluating a Transaction_Event, THE Promotion_Engine SHALL retrieve campaigns from Redis cache only
4. THE Promotion_Engine SHALL achieve P99_Latency below 1 millisecond for cache retrieval operations
5. WHEN a Campaign is updated via Admin_API, THE Promotion_Engine SHALL invalidate the corresponding Redis cache entry
6. WHEN a Campaign is paused or deleted, THE Promotion_Engine SHALL remove it from Redis cache within 100 milliseconds
7. THE Promotion_Engine SHALL set Redis TTL for campaign cache entries to match campaign expiry time
8. IF Redis becomes unavailable, THEN THE Promotion_Engine SHALL log an error and fall back to PostgreSQL with degraded performance
9. THE Promotion_Engine SHALL expose a cache hit ratio metric to Prometheus
10. WHEN the Expiry_Sweeper runs, THE Promotion_Engine SHALL remove expired campaigns from Redis cache

### Requirement 3: Idempotency Guarantee

**User Story:** As a Compliance Officer, I want strict idempotency for transaction processing, so that users never receive duplicate rewards even during Kafka message redelivery.

#### Acceptance Criteria

1. WHEN processing a Transaction_Event, THE Promotion_Engine SHALL check for Idempotency_Key `promo:processed:{transactionId}` in Redis
2. IF the Idempotency_Key exists in Redis, THEN THE Promotion_Engine SHALL skip processing and acknowledge the message
3. WHEN successfully applying a promotion, THE Promotion_Engine SHALL set the Idempotency_Key in Redis with 7-day TTL
4. THE Promotion_Engine SHALL use Redis SETNX operation for atomic idempotency key creation
5. WHEN Kafka redelivers a message, THE Promotion_Engine SHALL detect the duplicate and prevent re-evaluation
6. THE Promotion_Engine SHALL log all duplicate detection events with transaction ID and timestamp
7. THE Promotion_Engine SHALL expose a metric counting duplicate messages detected
8. IF Redis is unavailable during idempotency check, THEN THE Promotion_Engine SHALL reject the message and trigger retry
9. THE Promotion_Engine SHALL achieve 100% idempotency (zero duplicate rewards) under load testing with 10,000 TPS
10. WHEN processing completes, THE Promotion_Engine SHALL include the idempotency key in the Applied_Promotion record

### Requirement 4: Distributed Quota Management

**User Story:** As a Bank Admin, I want to set campaign quota limits like "First 1000 users get $5", so that I can control promotion costs and create urgency for customers.

#### Acceptance Criteria

1. WHEN creating a Campaign, THE Admin_API SHALL accept an optional quota_limit parameter (integer)
2. THE Promotion_Engine SHALL use Redisson distributed locks with key pattern `lock:quota:{campaignId}`
3. WHEN evaluating a transaction against a quota-limited Campaign, THE Promotion_Engine SHALL acquire a Distributed_Lock before incrementing the counter
4. THE Promotion_Engine SHALL store quota counters in Redis with key pattern `quota:used:{campaignId}`
5. IF the quota counter reaches the quota_limit, THEN THE Promotion_Engine SHALL mark the Campaign as QUOTA_EXHAUSTED and skip further evaluations
6. THE Promotion_Engine SHALL release the Distributed_Lock within 50 milliseconds
7. WHEN 50 service instances process transactions concurrently, THE Promotion_Engine SHALL prevent race conditions and ensure accurate quota counting
8. IF a Distributed_Lock acquisition times out after 200 milliseconds, THEN THE Promotion_Engine SHALL skip the promotion and log a warning
9. THE Promotion_Engine SHALL expose metrics for lock acquisition time and lock contention rate
10. WHEN a Campaign with quota_limit=1000 is tested under load, THE Promotion_Engine SHALL apply exactly 1000 promotions (no more, no less)

### Requirement 5: Outbox Pattern Implementation

**User Story:** As a DevOps Engineer, I want atomic consistency between database writes and Kafka events, so that the system never loses reward events even if Kafka brokers fail.

#### Acceptance Criteria

1. WHEN applying a promotion, THE Promotion_Engine SHALL save the Applied_Promotion record and outbox entry in a single PostgreSQL transaction
2. THE Promotion_Engine SHALL create an outbox table with columns: id, event_type, payload, created_at, processed_at, status
3. THE Promotion_Engine SHALL insert a Reward_Event into the outbox table with status=PENDING
4. THE Promotion_Engine SHALL implement an outbox polling mechanism using Spring @Scheduled with virtual threads
5. WHEN the outbox poller runs, THE Promotion_Engine SHALL select PENDING events and publish them to Kafka
6. WHEN a Reward_Event is successfully published to Kafka, THE Promotion_Engine SHALL update the outbox entry status to PROCESSED
7. THE outbox poller SHALL run every 100 milliseconds to minimize event dispatch latency
8. IF Kafka is unavailable, THEN THE Promotion_Engine SHALL leave events in PENDING status and retry on next poll
9. THE Promotion_Engine SHALL expose metrics for outbox queue depth and processing lag
10. WHEN tested with Kafka broker failures, THE Promotion_Engine SHALL achieve zero event loss and eventual consistency

### Requirement 6: Dead Letter Queue Strategy

**User Story:** As a DevOps Engineer, I want failed messages routed to a DLQ after retries, so that one bad message doesn't block an entire Kafka partition and halt promotion processing.

#### Acceptance Criteria

1. THE Promotion_Engine SHALL configure Kafka consumer with max retry attempts = 3
2. WHEN a message fails processing 3 times, THE Promotion_Engine SHALL publish it to the DLQ topic `titan.promotions.transactions.dlq`
3. THE Promotion_Engine SHALL include failure metadata in DLQ messages (error_message, retry_count, original_timestamp, stack_trace)
4. WHEN a message is sent to DLQ, THE Promotion_Engine SHALL log the failure with ERROR level and transaction ID
5. THE Promotion_Engine SHALL acknowledge the original message after DLQ publication to unblock the partition
6. THE Promotion_Engine SHALL expose a metric counting messages sent to DLQ
7. THE Admin_API SHALL provide an endpoint to list DLQ messages with pagination
8. THE Admin_API SHALL provide an endpoint to replay a DLQ message back to the main topic
9. WHEN a DLQ message is replayed, THE Promotion_Engine SHALL reset the retry counter
10. THE Promotion_Engine SHALL alert DevOps_Engineer when DLQ message count exceeds 100 in a 5-minute window

### Requirement 7: Asynchronous Ledger Integration

**User Story:** As an End User, I want my account credited automatically when I earn a promotion, so that I receive rewards without manual intervention.

#### Acceptance Criteria

1. WHEN a promotion is applied, THE Promotion_Engine SHALL publish a Reward_Event to Kafka topic `titan.rewards.granted`
2. THE Reward_Event SHALL contain userId, amount, currency, promotionId, transactionId, and timestamp
3. THE Promotion_Engine SHALL set the Applied_Promotion status to REWARD_PENDING after publishing the event
4. THE Promotion_Engine SHALL consume acknowledgment events from Kafka topic `titan.rewards.acknowledged`
5. WHEN receiving a reward acknowledgment, THE Promotion_Engine SHALL update the Applied_Promotion status to REWARD_DISBURSED
6. THE Promotion_Engine SHALL implement a timeout mechanism for reward acknowledgments (default: 30 seconds)
7. IF no acknowledgment is received within the timeout period, THEN THE Promotion_Engine SHALL mark the Applied_Promotion as REWARD_TIMEOUT and trigger an alert
8. THE Promotion_Engine SHALL retry reward dispatch up to 3 times for REWARD_TIMEOUT cases
9. THE Promotion_Engine SHALL expose metrics for reward dispatch latency and timeout rate
10. WHEN titan-core-banking is unavailable, THE Promotion_Engine SHALL continue processing promotions and queue rewards for eventual delivery

### Requirement 8: Admin API for Campaign Management

**User Story:** As a Bank Admin, I want secure API endpoints to manage campaigns, so that I can create, pause, and update promotions without developer assistance.

#### Acceptance Criteria

1. THE Admin_API SHALL provide a gRPC endpoint CreateCampaign accepting name, description, rule_expression, reward_amount, start_date, end_date, and quota_limit
2. THE Admin_API SHALL provide a gRPC endpoint PauseCampaign accepting campaignId and returning success confirmation
3. THE Admin_API SHALL provide a gRPC endpoint UpdateCampaign accepting campaignId and updated fields
4. THE Admin_API SHALL provide a gRPC endpoint RevokeCampaign accepting campaignId and reason
5. THE Admin_API SHALL provide a gRPC endpoint ListCampaigns with filtering by status and pagination
6. WHEN a Bank_Admin calls any Admin_API endpoint, THE Promotion_Engine SHALL validate the user's role via titan-identity-service
7. IF the user lacks required permissions, THEN THE Admin_API SHALL return PERMISSION_DENIED error
8. WHEN a campaign is created, paused, or updated, THE Admin_API SHALL create an audit log entry with user_id, action, timestamp, and changes
9. THE Admin_API SHALL validate rule expressions before saving and return detailed syntax errors
10. THE Admin_API SHALL expose metrics for API request rate, error rate, and latency per endpoint

### Requirement 9: Campaign Expiry Management

**User Story:** As a DevOps Engineer, I want automated expiry handling for campaigns, so that expired promotions are removed from active evaluation without manual intervention.

#### Acceptance Criteria

1. THE Expiry_Sweeper SHALL run as a Spring @Scheduled job using virtual threads
2. THE Expiry_Sweeper SHALL execute daily at 2:00 AM server time
3. WHEN the Expiry_Sweeper runs, THE Promotion_Engine SHALL select all campaigns where end_date < current_date AND status = ACTIVE
4. THE Expiry_Sweeper SHALL update expired campaign status from ACTIVE to COMPLETED
5. WHEN a campaign is marked COMPLETED, THE Expiry_Sweeper SHALL remove it from Redis cache
6. THE Expiry_Sweeper SHALL process campaigns in batches of 100 to avoid long-running transactions
7. THE Expiry_Sweeper SHALL log the number of campaigns expired in each run
8. THE Expiry_Sweeper SHALL expose a metric for last successful run timestamp
9. IF the Expiry_Sweeper fails, THEN THE Promotion_Engine SHALL log the error and retry on next scheduled execution
10. THE Expiry_Sweeper SHALL complete execution within 5 minutes even with 10,000 active campaigns

### Requirement 10: Observability and Alerting

**User Story:** As a DevOps Engineer, I want comprehensive metrics and alerts for the promotion service, so that I can detect and resolve issues before they impact customers.

#### Acceptance Criteria

1. THE Promotion_Engine SHALL expose Kafka consumer lag metrics to Prometheus with labels for topic and partition
2. THE Promotion_Engine SHALL expose rule evaluation latency histogram with P50, P95, and P99 percentiles
3. THE Promotion_Engine SHALL expose counters for promotions_applied, promotions_skipped, and promotions_failed
4. THE Promotion_Engine SHALL expose Redis cache hit ratio and operation latency metrics
5. THE Promotion_Engine SHALL expose distributed lock acquisition time and contention rate metrics
6. THE Promotion_Engine SHALL expose outbox queue depth and processing lag metrics
7. THE Promotion_Engine SHALL expose DLQ message count and rate metrics
8. WHEN consumer lag exceeds 1000 messages, THE Promotion_Engine SHALL trigger a WARNING alert
9. WHEN consumer lag exceeds 5000 messages, THE Promotion_Engine SHALL trigger a CRITICAL alert
10. THE Promotion_Engine SHALL provide Grafana dashboard JSON with panels for all key metrics (throughput, latency, errors, lag, cache performance)

## Integration Points

### titan-core-banking
- Consumes Reward_Event messages from `titan.rewards.granted` topic
- Publishes acknowledgment events to `titan.rewards.acknowledged` topic
- Credits user accounts based on promotion rewards

### titan-identity-service
- Provides RBAC validation for Admin_API endpoints
- Returns user roles and permissions for authorization decisions

### Kafka Infrastructure
- Consumes Transaction_Event messages from `titan.transactions.completed` topic
- Publishes Reward_Event messages to `titan.rewards.granted` topic
- Consumes acknowledgment events from `titan.rewards.acknowledged` topic
- Routes failed messages to `titan.promotions.transactions.dlq` topic

### Redis Infrastructure
- Stores Active_Campaign cache with sub-millisecond read latency
- Manages Idempotency_Key entries with 7-day TTL
- Stores quota counters for campaign limit enforcement
- Provides Distributed_Lock coordination via Redisson

### PostgreSQL Database
- Persists Campaign configurations with rule expressions
- Stores Applied_Promotion records for audit trail
- Maintains outbox table for event publishing
- Stores audit logs for admin actions

### Prometheus/Grafana
- Scrapes metrics from Promotion_Engine /actuator/prometheus endpoint
- Displays real-time dashboards for system health
- Triggers alerts based on threshold violations
- Provides historical trend analysis

## Non-Functional Requirements

### Performance
- THE Promotion_Engine SHALL process 10,000 transactions per second during peak events
- THE Rule_Engine SHALL evaluate rules with P99_Latency below 1 millisecond
- THE Promotion_Engine SHALL maintain consumer lag below 1000 messages during normal operation
- THE Admin_API SHALL respond to campaign management requests within 200 milliseconds (P95)

### Reliability
- THE Promotion_Engine SHALL achieve 100% idempotency (zero duplicate rewards)
- THE Promotion_Engine SHALL achieve zero event loss through outbox pattern
- THE Promotion_Engine SHALL handle Kafka broker failures gracefully with automatic recovery
- THE Promotion_Engine SHALL handle Redis failures with degraded performance fallback

### Scalability
- THE Promotion_Engine SHALL support horizontal scaling to 50+ instances
- THE Distributed_Lock mechanism SHALL prevent race conditions across all instances
- THE Promotion_Engine SHALL handle 100,000+ active campaigns efficiently
- THE Redis cache SHALL support 1 million+ cache entries

### Security
- THE Admin_API SHALL enforce RBAC for all campaign management operations
- THE Admin_API SHALL audit all administrative actions with user attribution
- THE Promotion_Engine SHALL validate and sanitize all SpEL expressions to prevent code injection
- THE Admin_API SHALL use TLS encryption for all gRPC communications

### Maintainability
- THE Promotion_Engine SHALL use Java 21 virtual threads for high-concurrency operations
- THE Promotion_Engine SHALL follow Spring Boot 3.x best practices
- THE Promotion_Engine SHALL provide comprehensive logging at appropriate levels
- THE Promotion_Engine SHALL expose health check endpoints for orchestration platforms
