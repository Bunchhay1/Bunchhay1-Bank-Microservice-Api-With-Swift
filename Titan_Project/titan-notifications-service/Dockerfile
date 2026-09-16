# =============================================================================
# Dockerfile — titan-notifications-service
#
# BUILD CONTEXT must be the repo ROOT (Titan_Project/) because this service
# depends on titan-event-consumer-lib which lives next to it.
#
# Local:  docker build -f titan-notifications-service/Dockerfile -t titan-notifications .
# Render: dockerContext: .   (set in render.yaml — repo root)
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────
FROM gradle:8-jdk21 AS build
WORKDIR /app

# 1. Build and publish titan-event-consumer-lib to local Maven cache
COPY titan-event-consumer-lib/ ./titan-event-consumer-lib/
RUN cd titan-event-consumer-lib && gradle publishToMavenLocal --no-daemon -q

# 2. Copy notifications service source
COPY titan-notifications-service/build.gradle titan-notifications-service/settings.gradle ./titan-notifications-service/
COPY titan-notifications-service/src ./titan-notifications-service/src

# 3. Build the fat JAR (skip tests — they need Kafka/DB)
RUN cd titan-notifications-service && gradle clean bootJar -x test --no-daemon

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

COPY --from=build /app/titan-notifications-service/build/libs/*-SNAPSHOT.jar app.jar

EXPOSE 8084

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8084/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
