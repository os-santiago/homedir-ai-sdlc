####
# Multi-stage Dockerfile for AI-SDLC Events Service
####

# Stage 1: Build
FROM maven:3.9-eclipse-temurin-21 AS build

WORKDIR /build

# Copy pom.xml and download dependencies (cached layer)
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copy source and build
COPY src ./src
RUN mvn clean package -DskipTests -B

# Stage 2: Runtime
FROM eclipse-temurin:21-jre-alpine

LABEL org.opencontainers.image.source="https://github.com/os-santiago/homedir-ai-sdlc"
LABEL org.opencontainers.image.description="AI-SDLC Events Service"
LABEL org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Create non-root user
RUN addgroup -S aisdlc && adduser -S aisdlc -G aisdlc

# Copy JAR from build stage
COPY --from=build /build/target/quarkus-app/lib/ /app/lib/
COPY --from=build /build/target/quarkus-app/*.jar /app/
COPY --from=build /build/target/quarkus-app/app/ /app/app/
COPY --from=build /build/target/quarkus-app/quarkus/ /app/quarkus/

# Set ownership
RUN chown -R aisdlc:aisdlc /app

USER aisdlc

EXPOSE 8080

ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar /app/quarkus-run.jar"]
