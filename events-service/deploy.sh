#!/bin/bash
# AI-SDLC Events Service - Deployment Automatizado Completo
# Versión Bash para Linux/Mac

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AI-SDLC Events Service - Auto Deploy${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Verificar Docker
echo -e "${YELLOW}Step 1: Verificando Docker...${NC}"

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✓ Docker ya está instalado: $DOCKER_VERSION${NC}"
else
    echo -e "${RED}Docker no está instalado${NC}"
    echo ""
    echo -e "${YELLOW}Instala Docker desde:${NC}"
    echo -e "${BLUE}  https://docs.docker.com/get-docker/${NC}"
    echo ""
    echo "Para Ubuntu/Debian:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo ""
    exit 1
fi

# Step 2: Verificar Docker daemon
echo ""
echo -e "${YELLOW}Step 2: Verificando Docker daemon...${NC}"

if docker ps &> /dev/null; then
    echo -e "${GREEN}✓ Docker daemon está corriendo${NC}"
else
    echo -e "${RED}Docker daemon no está corriendo${NC}"
    echo "Inicia Docker con: sudo systemctl start docker"
    exit 1
fi

# Step 3: Detener contenedores existentes
echo ""
echo -e "${YELLOW}Step 3: Limpiando deployment anterior...${NC}"

docker-compose down &> /dev/null || true
echo -e "${GREEN}✓ Limpieza completada${NC}"

# Step 4: Compilar aplicación
echo ""
echo -e "${YELLOW}Step 4: Compilando aplicación...${NC}"

./mvnw clean package -DskipTests
if [ $? -ne 0 ]; then
    echo -e "${RED}Error compilando aplicación${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Aplicación compilada exitosamente${NC}"

# Step 5: Construir imagen Docker
echo ""
echo -e "${YELLOW}Step 5: Construyendo imagen Docker...${NC}"

docker build -f deployment/docker/Containerfile -t ai-sdlc-events:latest .
if [ $? -ne 0 ]; then
    echo -e "${RED}Error construyendo imagen Docker${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Imagen Docker construida${NC}"

# Step 6: Iniciar servicios
echo ""
echo -e "${YELLOW}Step 6: Iniciando servicios...${NC}"

docker-compose up -d
if [ $? -ne 0 ]; then
    echo -e "${RED}Error iniciando servicios${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Servicios iniciados${NC}"

# Step 7: Esperar a PostgreSQL
echo ""
echo -e "${YELLOW}Step 7: Esperando a PostgreSQL...${NC}"

for i in {1..30}; do
    if docker exec ai-sdlc-postgres pg_isready -U aisdlc &> /dev/null; then
        echo -e "${GREEN}✓ PostgreSQL está listo${NC}"
        break
    fi
    echo -n "."
    sleep 1
done
echo ""

# Step 8: Esperar a la aplicación
echo ""
echo -e "${YELLOW}Step 8: Esperando a la aplicación...${NC}"

for i in {1..60}; do
    if curl -sf http://localhost:8080/api/health/live &> /dev/null; then
        echo -e "${GREEN}✓ Aplicación está lista${NC}"
        break
    fi
    if [ $((i % 10)) -eq 0 ]; then
        echo -n "."
    fi
    sleep 1
done
echo ""

# Step 9: Verificar deployment
echo ""
echo -e "${YELLOW}Step 9: Verificando deployment...${NC}"
echo ""

echo -e "${BLUE}Contenedores corriendo:${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo -e "${BLUE}Estado de salud:${NC}"
curl -s http://localhost:8080/api/health/status | jq '.' 2>/dev/null || echo "Aplicación aún iniciando..."
echo ""

# Success!
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Deployment completado exitosamente!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${BLUE}Accede a la aplicación:${NC}"
echo -e "  Dashboard:    ${NC}http://localhost:8080/dashboard/"
echo -e "  API Docs:     ${NC}http://localhost:8080/q/swagger-ui"
echo -e "  Health:       ${NC}http://localhost:8080/api/health/status"
echo -e "  Metrics:      ${NC}http://localhost:8080/q/metrics"
echo ""

echo -e "${BLUE}Gestión:${NC}"
echo -e "  Ver logs:     ${NC}docker logs -f ai-sdlc-app"
echo -e "  Detener:      ${NC}docker-compose down"
echo -e "  Reiniciar:    ${NC}docker-compose restart"
echo ""

echo -e "${BLUE}Test rápido:${NC}"
echo -e '  curl -X POST http://localhost:8080/internal/events/issue-detected \'
echo -e '    -H "Content-Type: application/json" \'
echo -e '    -d '"'"'{"issueNumber": 1000, "metadata": {"title": "Test"}}'"'"
echo ""
