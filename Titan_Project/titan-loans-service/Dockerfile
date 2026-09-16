# =============================================================================
# Titan Loans Service — Dockerfile
# Multi-stage build: Gradle build → minimal JRE runtime
# Compatible with Apple Silicon (linux/arm64) and amd64
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jdk AS builder

WORKDIR /app

# Copy Gradle wrapper and config first (layer cache)
COPY gradlew settings.gradle build.gradle ./
COPY gradle gradle/

RUN chmod +x ./gradlew

# Download dependencies (cached unless build.gradle changes)
RUN ./gradlew dependencies --no-daemon -q 2>/dev/null || true

# Copy source and build
COPY src src/
RUN ./gradlew bootJar --no-daemon -x test

# ── Stage 2: Runtime ──────────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre

WORKDIR /app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8085

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -Djava.security.egd=file:/dev/./urandom -jar app.jar"]
