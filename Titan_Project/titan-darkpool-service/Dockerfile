# =============================================================================
# Dockerfile — titan-darkpool-service
#
# Simple dark pool service for anonymous institutional trading
#
# Local:  docker build -f titan-darkpool-service/Dockerfile -t titan-darkpool-service .
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────
FROM gradle:8-jdk21 AS build
WORKDIR /app

# 2. Copy dark pool service source
COPY build.gradle settings.gradle ./titan-darkpool-service/
COPY src ./titan-darkpool-service/src

# 3. Build the fat JAR (skip tests — they need Kafka/DB for integration)
RUN cd titan-darkpool-service && gradle clean bootJar -x test --no-daemon

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

COPY --from=build /app/titan-darkpool-service/build/libs/titan-darkpool-service-*.jar app.jar

EXPOSE 8090

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8090/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]