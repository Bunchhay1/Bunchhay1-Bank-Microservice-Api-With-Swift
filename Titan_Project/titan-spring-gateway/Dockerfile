# =============================================================================
# Dockerfile — titan-spring-gateway
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────
FROM gradle:8-jdk21 AS build
WORKDIR /app

COPY build.gradle settings.gradle* ./
COPY src ./src

# Build fat JAR, skip tests
RUN gradle clean bootJar -x test --no-daemon

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# bootJar always produces exactly one *-SNAPSHOT.jar or *.jar named after the
# project version. Copy to a fixed name so COPY never gets multiple sources.
COPY --from=build /app/build/libs/titan-spring-gateway-*.jar app.jar

EXPOSE 2020

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=5 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:2020/actuator/health || exit 1

ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS:-} -jar app.jar"]
