#!/bin/bash
# AI-SDLC Events Service - Podman Pod Setup
# Creates a pod with PostgreSQL and AI-SDLC containers

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AI-SDLC Events Service - Pod Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
POD_NAME="ai-sdlc-events-pod"
POSTGRES_CONTAINER="ai-sdlc-postgres"
APP_CONTAINER="ai-sdlc-app"
DB_NAME="aisdlc"
DB_USER="aisdlc"
DB_PASSWORD="aisdlc"
APP_PORT=8080

# Step 1: Stop and remove existing pod if exists
echo -e "${YELLOW}Step 1: Cleaning up existing pod...${NC}"
podman pod exists ${POD_NAME} && podman pod rm -f ${POD_NAME} || echo "No existing pod found"
echo ""

# Step 2: Create pod
echo -e "${YELLOW}Step 2: Creating pod '${POD_NAME}'...${NC}"
podman pod create \
  --name ${POD_NAME} \
  --publish ${APP_PORT}:8080
echo -e "${GREEN}✓ Pod created${NC}"
echo ""

# Step 3: Start PostgreSQL container
echo -e "${YELLOW}Step 3: Starting PostgreSQL container...${NC}"
podman run -d \
  --pod ${POD_NAME} \
  --name ${POSTGRES_CONTAINER} \
  -e POSTGRES_DB=${DB_NAME} \
  -e POSTGRES_USER=${DB_USER} \
  -e POSTGRES_PASSWORD=${DB_PASSWORD} \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  docker.io/library/postgres:16-alpine

echo -e "${GREEN}✓ PostgreSQL container started${NC}"
echo ""

# Step 4: Wait for PostgreSQL to be ready
echo -e "${YELLOW}Step 4: Waiting for PostgreSQL to be ready...${NC}"
sleep 5
for i in {1..30}; do
  if podman exec ${POSTGRES_CONTAINER} pg_isready -U ${DB_USER} > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PostgreSQL is ready${NC}"
    break
  fi
  echo -n "."
  sleep 1
done
echo ""

# Step 5: Build AI-SDLC application image
echo -e "${YELLOW}Step 5: Building AI-SDLC application image...${NC}"
cd "$(dirname "$0")/.."

# Package application
echo "Packaging application..."
./mvnw clean package -DskipTests

# Build container image
echo "Building container image..."
podman build -f deployment/docker/Containerfile -t ai-sdlc-events:latest .
echo -e "${GREEN}✓ Application image built${NC}"
echo ""

# Step 6: Start AI-SDLC application container
echo -e "${YELLOW}Step 6: Starting AI-SDLC application container...${NC}"
podman run -d \
  --pod ${POD_NAME} \
  --name ${APP_CONTAINER} \
  -e QUARKUS_DATASOURCE_REACTIVE_URL=postgresql://localhost:5432/${DB_NAME} \
  -e QUARKUS_DATASOURCE_USERNAME=${DB_USER} \
  -e QUARKUS_DATASOURCE_PASSWORD=${DB_PASSWORD} \
  -e QUARKUS_DATASOURCE_JDBC_URL=jdbc:postgresql://localhost:5432/${DB_NAME} \
  ai-sdlc-events:latest

echo -e "${GREEN}✓ Application container started${NC}"
echo ""

# Step 7: Wait for application to be ready
echo -e "${YELLOW}Step 7: Waiting for application to be ready...${NC}"
sleep 10
for i in {1..60}; do
  if curl -s http://localhost:${APP_PORT}/api/health/live > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is ready${NC}"
    break
  fi
  echo -n "."
  sleep 1
done
echo ""

# Step 8: Verify deployment
echo -e "${YELLOW}Step 8: Verifying deployment...${NC}"
echo ""

# Check pod status
echo "Pod status:"
podman pod ps --filter name=${POD_NAME}
echo ""

# Check containers
echo "Containers in pod:"
podman ps --filter pod=${POD_NAME}
echo ""

# Check health
echo "Application health:"
curl -s http://localhost:${APP_PORT}/api/health/status | jq '.' 2>/dev/null || echo "Health endpoint not ready yet"
echo ""

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Pod deployment completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Access the application:"
echo -e "  ${BLUE}Dashboard:${NC}    http://localhost:${APP_PORT}/dashboard/"
echo -e "  ${BLUE}API Docs:${NC}     http://localhost:${APP_PORT}/q/swagger-ui"
echo -e "  ${BLUE}Health:${NC}       http://localhost:${APP_PORT}/api/health/status"
echo -e "  ${BLUE}Metrics:${NC}      http://localhost:${APP_PORT}/q/metrics"
echo ""
echo "Manage the pod:"
echo -e "  ${BLUE}View logs:${NC}    podman logs -f ${APP_CONTAINER}"
echo -e "  ${BLUE}Stop pod:${NC}     podman pod stop ${POD_NAME}"
echo -e "  ${BLUE}Start pod:${NC}    podman pod start ${POD_NAME}"
echo -e "  ${BLUE}Remove pod:${NC}   podman pod rm -f ${POD_NAME}"
echo ""
echo "Test the API:"
echo -e "  ${BLUE}curl -X POST http://localhost:${APP_PORT}/internal/events/issue-detected \\${NC}"
echo -e "    ${BLUE}-H \"Content-Type: application/json\" \\${NC}"
echo -e "    ${BLUE}-d '{\"issueNumber\": 1000, \"metadata\": {\"title\": \"Test\"}}' | jq${NC}"
echo ""
