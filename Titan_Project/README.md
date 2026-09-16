# 🏦 Titan Banking Platform

![Status](https://img.shields.io/badge/STATUS-OPERATIONAL-brightgreen)
![Version](https://img.shields.io/badge/VERSION-1.0.0-blue)
![Security](https://img.shields.io/badge/SECURITY-IRONCLAD-red)

> **Operation:** Ironclad (End-to-End Secure Banking System)

## 📖 Platform Overview

Titan Banking is a high-performance, distributed banking system designed with a **Microservices Architecture**. It simulates a real-world financial backend featuring military-grade security, AI-powered fraud detection, and real-time observability.

The platform leverages a polyglot approach—using the best language for each specific task:
- **Java** (Spring Boot) for core banking logic and transactional integrity
- **Golang** for high-speed API gateway and edge services
- **Python** for AI/ML-powered fraud detection and analytics
- **Infrastructure**: PostgreSQL, Redis, Kafka, Docker, Kubernetes

## 🏗️ System Architecture

The system utilizes a hybrid microservices approach with loose coupling via event streaming (Kafka) and synchronous communication (REST/gRPC) where needed.

```
┌─────────────────────────────────────────────────────────────────────┐
│                       CLIENT APPLICATIONS                           │
│  (Mobile/Web)                                                       │
└───────────────▲─────────────────────────────────────────────────────┘
                │
┌───────────────▼─────────────────────────────────────────────────────┐
│                    TITAN GATEWAY GO (API Gateway)                   │
│  - JWT Authentication • Rate Limiting • Reverse Proxy               │
│  - Port: 8088                                                       │
└───────────────▲─────────────────────────────────────────────────────┘
                │
     ┌──────────┴───────────┐    ┌──────────┴───────────┐    ┌──────────┴───────────┐
     ▼                      ▼    ▼                      ▼    ▼                      ▼
┌─────────────┐    ┌──────────────┐    ┌────────────────┐    ┌──────────────────┐
│ CORE        │    │ NOTIFICATIONS│    │ PROMOTIONS     │    │ DARK POOL        │
│ BANKING     │    │ SERVICE      │    │ SERVICE        │    │ SERVICE          │
│ (Java)      │    │ (Java)       │    │ (Java)         │    │ (Java)           │
│ - 8080      │    │ - 8084       │    │ - 8083         │    │ - 8085           │
└──────────▲──┘    └───────▲──────┘    └──────────▲─────┘    └──────────▲───────┘
           │               │                      │                      │
           │               │                      │                      │
     ┌─────┴─────┐ ┌───────┴───────┐   ┌──────────┴──────────┐ ┌────────┴────────┐
     │           │ │               │   │                     │ │                 │
     ▼           ▼ ▼               ▼   ▼                     ▼ ▼                 ▼
┌─────────────┐ ┌──────────────┐ ┌────────────────┐ ┌──────────────────┐
│ RISK ENGINE │ │   KAFKA      │ │   POSTGRESQL   │ │    REDIS         │
│ (Python)    │ │ (Event Bus)  │ │ (Primary DB)   │ │ (Cache/OTP/Rate) │
│ - gRPC:50051│ │              │ │                │ │                  │
└─────────────┘ └──────────────┘ └────────────────┘ └──────────────────┘
```

### Key Architectural Principles
- **Service Independence**: Each service owns its data domain and communicates via well-defined APIs
- **Event-Driven**: Kafka enables asynchronous communication for scalability and resilience
- **Polyglot Pragmatism**: Language chosen per service based on strengths (Java for transactions, Go for performance, Python for ML)
- **Defense-in-Depth**: Security layered at network, application, and data levels
- **Observability-First**: Metrics, logs, and traces instrumented from the start

## 🧩 Services Overview

| Service | Technology | Port | Description | README |
|---------|------------|------|-------------|--------|
| **Titan Core Banking** | Java Spring Boot 3 | 8080 | Central banking engine handling accounts, transactions, and ledger with ACID compliance | [titan-core-banking/README.md](titan-core-banking/README.md) |
| **Titan Gateway Go** | Golang (Gin/Fiber) | 8088 | API gateway providing JWT auth, rate limiting, and reverse proxy to downstream services | [titan-gateway-go/README.md](titan-gateway-go/README.md) |
| **Titan Notifications Service** | Java Spring Boot 3.2 | 8084 | Real-time omnichannel notification platform with WebSocket, AI-driven delivery, and compliance features | [titan-notifications-service/README.md](titan-notifications-service/README.md) |
| **Titan Promotions Service** | Java Spring Boot | 8083 | Gamification, loyalty programs, and merchant federation with Neo4j, GraphQL, and WASM edge offloading | [titan-promotions-service/PHASE8-README.md](titan-promotions-service/PHASE8-README.md) |
| **Titan AI Service** | Python gRPC | 5005 | Fraud detection engine providing risk scoring for transactions | [titan-ai-service/README.md](titan-ai-service/README.md) |
| **Titan Dark Pool Service** | Java | 8085 | Anonymous, high-frequency order matching for institutional trading | [titan-darkpool-service/README.md](titan-darkpool-service/README.md) |
| **Titan Edge AI** | Python/WebAssembly | 8096 | Client-side fraud detection model running entirely in browser for zero-latency, privacy-first inference | [titan-edge-ai/README.md](titan-edge-ai/README.md) |

## 🚀 Getting Started

### Prerequisites
- Docker & Docker Compose
- Java 21 (for local development)
- Python 3.x (for test scripts)
- (Optional) Proxmox for VM control (mentioned in docs)

### Quick Start
```bash
# 1. Clone the repository
git clone https://github.com/bunchhay1/titan-core-banking.git
cd titan-core-banking

# 2. Deploy Infrastructure (Debian/Linux/Mac)
docker compose up -d --build

# 3. Verify Services
docker compose ps

# 4. View Logs
docker compose logs -f titan-core-banking titan-notifications-service

# 5. Access Services
- Core Banking API: http://localhost:8080
- Gateway: http://localhost:8088
- Notifications: http://localhost:8084
- Promotions: http://localhost:8083
- Adminer (DB UI): http://localhost:8080 (via separate setup if needed)
```

### Service-Specific Commands
```bash
# Core Banking
./gradlew :titan-core-banking:build
./gradlew :titan-core-banking:bootRun

# Notifications Service
./gradlew :titan-notifications-service:build
./gradlew :titan-notifications-service:bootRun

# Promotions Service
./gradlew :titan-promotions-service:build
./gradlew :titan-promotions-service:bootRun

# Gateway Go
go build -o titan-gateway-go ./titan-gateway-go
./titan-gateway-go

# AI Service
python3 titan-ai-service/main.py
```

## 🔧 Technology Stack

### Backend Languages
- **Java 21**: Spring Boot 3 (Core Banking, Notifications, Promotions, Dark Pool)
- **Golang 1.22**: Gin/Fiber (API Gateway)
- **Python 3.11**: gRPC/scikit-learn (AI Service, Edge AI)

### Data & Messaging
- **PostgreSQL 15**: Primary relational database (multiple schemas)
- **Redis 7**: Caching, OTP storage, rate limiting, quest states
- **Apache Kafka**: Event streaming backbone (KRaft mode, no Zookeeper)
- **Neo4j 5.15**: Referral graph for promotions (Promotions Service)
- **MinIO**: S3-compatible storage for Iceberg exports (Promotions Service)

### Infrastructure & DevOps
- **Docker**: Containerization
- **Docker Compose**: Local orchestration
- **Kubernetes**: Production deployment manifests (k8s/ directory)
- **Gradle/Maven**: Java build systems
- **Go Modules**: Golang dependency management
- **pip**: Python package management

### Monitoring & Observability
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and alerting
- **Micrometer**: Java metrics instrumentation
- **expvar**: Go metrics exposure
- **prometheus_client**: Python metrics
- **ELK Stack**: Log aggregation (implied from logging configs)

### Security & Compliance
- **JWT**: Stateless authentication (HS256)
- **OAuth2/OpenID Connect**: Framework ready (configurable)
- **HashiCorp Vault**: Secret management and credential rotation
- **BouncyCastle**: S/MIME email cryptography
- **Spring Security**: Authentication and authorization
- **OWASP Dependency-Check**: Vulnerability scanning
- **Qodana**: Code quality and security analysis

### AI/ML
- **scikit-learn**: Model training (Python)
- **Pure JavaScript**: Client-side inference (Edge AI)
- **WebAssembly**: Target for high-performance rules (Promotions Service)
- **Protobufs**: Service contracts (gRPC)

## 📊 Monitoring and Observability

Titan Banking includes comprehensive observability out-of-the-box:

### Metrics Collected
- **JVM**: Memory, GC, thread counts
- **API**: Request rates, latency, error rates (by endpoint)
- **Business**: Transaction volume, account creation, notification delivery
- **Infrastructure**: CPU, memory, disk, network usage
- **Kafka**: Consumer lag, throughput, broker metrics
- **Redis**: Hit/miss rates, memory usage, connected clients
- **WebSocket**: Connection counts, message latency, broadcast efficiency

### Key Dashboards (Grafana)
1. **System Overview**: Infrastructure health at a glance
2. **Service Health**: Per-service latency, error rates, throughput
3. **Transaction Monitoring**: Banking operation metrics
4. **Real-time Alerts**: Notification delivery and WebSocket performance
5. **AI Model Performance**: Risk scoring distribution and latency
6. **Business KPIs**: User growth, engagement, promotion effectiveness

### Logging
- Structured JSON logging with correlation IDs
- Centralized collection via Fluentd/Filebeat (production)
- PII redaction at log ingestion point
- Audit trails for all financial operations (WORM storage)

### Health Checks
- Kubernetes liveness/readiness probes for all services
- gRPC health checking for internal services
- Circuit breaker patterns for external dependencies
- Automated restart on failure

## 🔒 Security Features (Operation Ironclad)

### Authentication & Authorization
- **Stateless JWT**: Short-lived tokens with refresh mechanism
- **Multi-Factor Authentication**: OTP for high-value transfers (>$10k)
- **Role-Based Access Control**: Fine-grained permissions per service
- **Service-to-Service Auth**: Mutual TLS and JWT for internal communication

### Data Protection
- **Encryption-in-Transit**: TLS 1.3 for all service communication
- **Encryption-at-Rest**: AES-256 for databases and backups
- **Field-Level Encryption**: Sensitive data (PII) in logs and backups
- **Key Management**: Automated rotation via HashiCorp Vault
- **Secrets Management**: No hardcoded credentials (environment/Vault)

### Application Security
- **Input Validation**: Strict validation at all service boundaries
- **Idempotency**: Unique request headers preventing duplicate transactions
- **Account Protection**: Smart lockout (5 failed attempts temporary, 7 permanent)
- **Transaction Monitoring**: Real-time AI risk scoring + rule-based thresholds
- **Secure Headers**: CSP, HSTS, X-Frame-Options implemented
- **Dependency Scanning**: Automated vulnerability checks in CI/CD

### Network & Infrastructure
- **Rate Limiting**: Token bucket algorithm (100 req/s/IP) at gateway
- **DDoS Protection**: Automatic IP blocking and escalation
- **Network Segmentation**: Private networks for different service tiers
- **Zero Trust Principles**: Never trust, always verify
- **Regular Penetration Testing**: Scheduled security assessments

### Compliance & Governance
- **GDPR/CCPA**: Data subject rights implementation, right to erasure
- **PCI-DSS**: Card data handling and storage compliance
- **SOX**: Financial audit trail and change management
- **MiFID II**: Anonymous trading compliance (Dark Pool Service)
- **7-Year Archival**: Immutable storage for regulatory requirements
- **Audit Logging**: Complete, tamper-evident records of all operations

## 💼 Why This Architecture Matters

### For Engineering Teams
- **Autonomy**: Teams own services end-to-end (build, test, deploy, operate)
- **Technology Choice**: Pick the right tool for the job (not one-size-fits-all)
- **Scalability**: Scale only the services experiencing load
- **Fault Isolation**: Failures contained to individual services
- **Deployment Frequency**: Multiple releases per day without system-wide risk

### For Business Stakeholders
- **Time-to-Market**: New features deployable in hours, not months
- **Resilience**: 99.9%+ uptime target with observable SLIs/SLOs
- **Compliance Built-In**: Reduced audit findings and remediation costs
- **Innovation Velocity**: Safe experimentation with new technologies (WASM, GraphQL)
- **Talent Attraction**: Modern stack appeals to senior engineering talent

### For Security & Risk Teams
- **Defense-in-Depth**: Multiple independent security controls
- **Real-Time Monitoring**: Anomaly detection and automated response
- **Audit Completeness**: Full traceability for forensic investigations
- **Privacy by Design**: Data minimization and purpose limitation
- **Regulatory Readiness**: Continuous compliance rather than point-in-time

## 📜 License

This project is part of the Titan Banking Platform. See individual service directories for specific license information.

## 🙏 Acknowledgments

- Architecture inspired by microservices best practices (Martin Fowler, Sam Newman)
- Security patterns from Google's BeyondCorp and Zero Trust models
- Financial systems design principles from industry standards (ISO 20022, PCI-DSS)
- Open-source community contributions to Spring Boot, Golang, PostgreSQL, Redis, Kafka

---

*Last updated: August 2026*  
*Platform Status: ✅ Production Ready*  
*Maintained by: The Titan Engineering Team*