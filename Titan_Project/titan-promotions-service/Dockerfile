# =============================================================================
# Dockerfile — titan-promotions-service
#
# BUILD CONTEXT: ./titan-promotions-service  (service root)
#
# Local build:
#   docker build -t titan-promotions-service ./titan-promotions-service
#
# Via docker-compose (builds automatically):
#   docker compose up -d --build titan-promotions-service
# =============================================================================

# ── Stage 1: Build ────────────────────────────────────────────────────────
FROM gradle:8-jdk21 AS build
WORKDIR /app

# Copy gradle wrapper + build files first (layer cache)
COPY build.gradle settings.gradle* ./

# Copy source
COPY src ./src

# Build the fat JAR — skip tests (need live DB/Kafka)
# GRADLE_OPTS forces the protobuf plugin to use linux-x86_64 classifier
# inside the builder container (gradle:8-jdk21 is amd64-based on Docker Hub).
ENV GRADLE_OPTS="-Dos.name=Linux -Dos.arch=x86_64 -Dos.detected.classifier=linux-x86_64"
RUN gradle clean bootJar -x test --no-daemon

# ── Stage 2: Runtime ──────────────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

# Copy the fat JAR produced by bootJar (always named *-SNAPSHOT.jar or *-PLAIN.jar;
# we exclude the plain jar with tasks.jar.enabled=false in build.gradle)
COPY --from=build /app/build/libs/*.jar app.jar

EXPOSE 8083

HEALTHCHECK --interval=30s --timeout=5s --start-period=90s --retries=5 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8083/actuator/health || exit 1

# JAVA_OPTS is injected by docker-compose for memory tuning
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
