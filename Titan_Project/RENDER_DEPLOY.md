# Titan Banking — Render Deployment Guide

## Pre-Deploy Checklist

### 1. Fix the Rust Gateway folder name (REQUIRED)
```bash
cd /Users/chhay/Desktop/banking/Titan_Project
mv "titan gateway " titan-gateway-rust
```
Folder names with spaces break Render's build system.

### 2. Add missing Dockerfiles (REQUIRED)
`titan-mpc-service` and `titan-fhe-service` directories are empty — you need to add Dockerfiles before deploying them.

### 3. Fix titan-edge-ai serve.py (REQUIRED)
The serve.py has a hardcoded local path. Replace it:
```python
# Change this line:
os.chdir('/Users/chhay/Documents/titan-project/titan-edge-ai')
# To:
os.chdir('/app')
```

### 4. Set up External Services (Free)

#### Kafka — Confluent Cloud (free)
1. Go to https://confluent.cloud → Sign up
2. Create a cluster → Basic (free)
3. Create API Key → copy Bootstrap Server URL
4. Paste in render.yaml: `KAFKA_BOOTSTRAP_SERVERS`

#### Redis — Upstash (free)
1. Go to https://upstash.com → Sign up
2. Create Redis database → Free tier
3. Copy Host and Port
4. Paste in render.yaml: `REDIS_HOST` and `REDIS_PORT`

---

## Deploy Steps

### Step 1 — Push to GitHub
```bash
cd /Users/chhay/Desktop/banking/Titan_Project
git init  # if not already
git add .
git commit -m "feat: add master render.yaml for all 20 services"
git remote add origin https://github.com/YOUR_USERNAME/titan-banking.git
git push -u origin main
```

### Step 2 — Connect to Render
1. Go to https://dashboard.render.com
2. Click **New** → **Blueprint**
3. Connect your GitHub repo
4. Render auto-detects `render.yaml` at root
5. Click **Apply** — Render provisions all services

### Step 3 — Fill in Environment Variables
After the blueprint is created, go to each service and fill in the `sync:false` INPUT BOX variables:

| Service | Variable | Where to get it |
|---------|----------|-----------------|
| All Java services | `KAFKA_BOOTSTRAP_SERVERS` | Confluent Cloud dashboard |
| All Java services | `REDIS_HOST` | Upstash dashboard |
| titan-notifications | `SENDGRID_API_KEY` | sendgrid.com |
| titan-notifications | `TWILIO_*` | twilio.com (optional) |
| titan-core-banking | `APNS_KEY_ID` | Apple Developer Portal (optional) |
| titan-core-banking | `APNS_TEAM_ID` | Apple Developer Portal (optional) |

### Step 4 — Manual Deploy
Click **Manual Deploy** → **Deploy latest commit** for each service in order:
1. Databases (auto-provisioned)
2. `titan-ai-service`
3. `titan-core-banking`
4. `titan-notifications-service`, `titan-promotions-service`
5. All other services
6. Gateways last

---

## Service URLs After Deploy

| Service | URL |
|---------|-----|
| titan-core-banking | https://titan-core-banking.onrender.com |
| titan-notifications-service | https://titan-notifications-service.onrender.com |
| titan-promotions-service | https://titan-promotions-service.onrender.com |
| titan-spring-gateway | https://titan-spring-gateway.onrender.com |
| titan-gateway-go | https://titan-gateway-go.onrender.com |
| titan-gateway-rust | https://titan-gateway-rust.onrender.com |
| titan-edge-ai | https://titan-edge-ai.onrender.com |
| titan-qkd-service | https://titan-qkd-service.onrender.com |
| titan-ai-service | Internal only (private service, no public URL) |

---

## Troubleshooting

### "OutOfMemoryError" on Java services
Increase heap in `JAVA_OPTS`:
```
-Xmx450m -Xms200m
```
Or upgrade to Render Starter plan ($7/month).

### Service won't start — "Connection refused" to Kafka
Set `KAFKA_ENABLED=false` — all services already have this default.

### Cold start too slow
Free tier sleeps after 15min. To keep warm, use a free uptime monitor:
- https://uptimerobot.com — ping `/actuator/health` every 5min

### Postgres "too many connections"
Free Postgres limits to 97 connections. With 8 Java services × 10 pool size = 80 connections.
Add to each service's env:
```
SPRING_DATASOURCE_HIKARI_MAXIMUM-POOL-SIZE=5
SPRING_DATASOURCE_HIKARI_MINIMUM-IDLE=2
```

### titan-ai-service not reachable from titan-core-banking
Both must be in the same Render region (Oregon by default).
`AI_HOST` should be `titan-ai-service` (Render's internal DNS for private services).

---

## Free Tier Cost Summary

| Resource | Provider | Cost |
|----------|----------|------|
| 3x Postgres | Render | Free |
| Redis | Upstash | Free (10k commands/day) |
| Kafka | Confluent Cloud | Free (up to 5GB/month) |
| 17x Web/Private Services | Render | Free (750 hrs/month each) |
| **Total** | | **$0/month** |

> Note: Free Render services share 750 compute hours/month per account.
> 17 services × 24h = 408h/day which exceeds free limits.
> **Recommendation**: Deploy only core services on free tier, upgrade critical ones to Starter ($7/month).
