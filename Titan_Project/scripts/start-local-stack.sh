#!/usr/bin/env bash
# =============================================================================
# Titan Banking — Start Local Stack
# - Infrastructure (PostgreSQL, Kafka, Redis): runs in Docker
# - Microservices (Core Banking, Notifications, Promotions, Gateway): runs on Mac host
# =============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DIR"

echo "========================================================="
echo " 1. Checking & Starting Docker Infrastructure"
echo "========================================================="

# Ensure Docker daemon (Colima / Docker Desktop) is active
if ! docker info > /dev/null 2>&1; then
    echo "Docker daemon not running. Attempting to start Colima..."
    colima start || { echo "Failed to start Colima/Docker. Please start Docker first."; exit 1; }
fi

# Start postgres, redis, kafka
docker compose up -d postgres redis kafka

echo "Waiting for PostgreSQL & Kafka to be ready..."
until docker exec titan-postgres pg_isready -U postgres -d titandb > /dev/null 2>&1; do
    sleep 2
done
echo "PostgreSQL is ready."

# Find Java 21
if [ -d "/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home" ]; then
    export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
elif [ -n "$JAVA_HOME" ]; then
    echo "Using existing JAVA_HOME: $JAVA_HOME"
else
    echo "Warning: openjdk@21 not found at default Homebrew path. Using current java:"
    which java
fi

echo "Java version:"
"$JAVA_HOME/bin/java" -version

mkdir -p "$DIR/logs"

echo "========================================================="
echo " 2. Starting Microservices on Mac Host"
echo "========================================================="

# Helper to check if port is in use
is_port_in_use() {
    lsof -iTCP:"$1" -sTCP:LISTEN -n -P > /dev/null 2>&1
}

# 1. Titan Core Banking (Port 8080)
if is_port_in_use 8080; then
    echo "Titan Core Banking already listening on port 8080."
else
    echo "Starting Titan Core Banking on port 8080..."
    (
        cd "$DIR/titan-core-banking"
        export DB_HOST=localhost
        export DB_PORT=5432
        export DB_NAME=titandb
        export DB_USERNAME=postgres
        export DB_PASSWORD='TitanDB$ecure2026_X9z!Lp'
        export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
        export REDIS_HOST=localhost
        export REDIS_PORT=6379
        nohup ./gradlew bootRun > "$DIR/logs/titan-core-banking.log" 2>&1 &
        echo $! > "$DIR/logs/titan-core-banking.pid"
    )
fi

# 2. Titan Notifications Service (Port 8084)
if is_port_in_use 8084; then
    echo "Titan Notifications Service already listening on port 8084."
else
    echo "Starting Titan Notifications Service on port 8084..."
    (
        cd "$DIR"
        export DB_HOST=localhost
        export DB_PORT=5432
        export DB_NAME=notificationdb
        export DB_USERNAME=postgres
        export DB_PASSWORD='TitanDB$ecure2026_X9z!Lp'
        export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/notificationdb
        export SPRING_DATASOURCE_USERNAME=postgres
        export SPRING_DATASOURCE_PASSWORD='TitanDB$ecure2026_X9z!Lp'
        export SPRING_KAFKA_BOOTSTRAPSERVERS=localhost:9092
        export KAFKA_BOOTSTRAP_SERVERS=localhost:9092
        export KAFKA_ENABLED=true
        export REDIS_HOST=localhost
        export REDIS_PORT=6379
        export SPRING_CLOUD_VAULT_ENABLED=false
        nohup ./gradlew :titan-notifications-service:bootRun > "$DIR/logs/titan-notifications-service.log" 2>&1 &
        echo $! > "$DIR/logs/titan-notifications-service.pid"
    )
fi

# 3. Titan Promotions Service (Port 8083)
if is_port_in_use 8083; then
    echo "Titan Promotions Service already listening on port 8083."
else
    echo "Starting Titan Promotions Service on port 8083..."
    (
        cd "$DIR"
        export DATABASE_URL=jdbc:postgresql://localhost:5432/promotiondb
        export DATABASE_USERNAME=postgres
        export DATABASE_PASSWORD='TitanDB$ecure2026_X9z!Lp'
        export SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/promotiondb
        export SPRING_DATASOURCE_USERNAME=postgres
        export SPRING_DATASOURCE_PASSWORD='TitanDB$ecure2026_X9z!Lp'
        export SPRING_KAFKA_BOOTSTRAPSERVERS=localhost:9092
        export REDIS_HOST=localhost
        export REDIS_PORT=6379
        nohup ./gradlew :titan-promotions-service:bootRun > "$DIR/logs/titan-promotions-service.log" 2>&1 &
        echo $! > "$DIR/logs/titan-promotions-service.pid"
    )
fi

# 4. Titan Gateway Go (Port 8088)
if is_port_in_use 8088; then
    echo "Titan Gateway Go already listening on port 8088."
else
    echo "Building & Starting Titan Gateway (Go) on port 8088..."
    (
        cd "$DIR/titan-gateway-go"
        go build -o gateway main.go
        nohup env CONFIG_PATH=config-local.yaml ./gateway > "$DIR/logs/titan-gateway-go.log" 2>&1 &
        echo $! > "$DIR/logs/titan-gateway-go.pid"
    )
fi

echo "========================================================="
echo " All services launched! Log files in: $DIR/logs/"
echo "========================================================="
