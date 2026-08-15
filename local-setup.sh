#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== AI-SDLC Local Setup ===${NC}"
echo ""

# Check prerequisites
echo -e "${GREEN}Checking prerequisites...${NC}"

# Check container runtime (podman or docker)
if command -v podman &> /dev/null; then
  CONTAINER_CMD="podman"
  echo "✓ Podman: $(podman --version)"
elif command -v docker &> /dev/null; then
  CONTAINER_CMD="docker"
  echo "✓ Docker: $(docker --version)"
else
  echo -e "${RED}ERROR: Neither podman nor docker found${NC}"
  echo "Install one of them first"
  exit 1
fi

# Check gh CLI
if ! command -v gh &> /dev/null; then
  echo -e "${RED}ERROR: GitHub CLI not found${NC}"
  echo "Install gh CLI first: https://cli.github.com/"
  exit 1
fi
echo "✓ GitHub CLI: $(gh --version | head -1)"

# Check environment variables
echo ""
echo -e "${GREEN}Checking environment variables...${NC}"

if [[ -z "${GH_TOKEN}" ]]; then
  echo -e "${YELLOW}WARNING: GH_TOKEN not set${NC}"
  echo "Set it with: export GH_TOKEN=<your-token>"
  echo "Or authenticate with: gh auth login"
else
  echo "✓ GH_TOKEN set"
fi

if [[ -z "${SC_API_KEY}" ]]; then
  echo -e "${YELLOW}WARNING: SC_API_KEY not set${NC}"
  echo "Set it with: export SC_API_KEY=<your-nvidia-api-key>"
  echo "Without it, SCC won't work but you can test infrastructure"
else
  echo "✓ SC_API_KEY set"
fi

# Create directory structure
echo ""
echo -e "${GREEN}Creating local directories...${NC}"

mkdir -p "${SCRIPT_DIR}/local-state"/{issues,prs,run-summaries,autonomous-decisions}
mkdir -p "${SCRIPT_DIR}/local-logs"

echo "✓ Created: ${SCRIPT_DIR}/local-state/"
echo "✓ Created: ${SCRIPT_DIR}/local-logs/"

# Build image
echo ""
echo -e "${GREEN}Building worker image...${NC}"

cd "${SCRIPT_DIR}"
${CONTAINER_CMD} build \
  -f container/Containerfile.worker \
  -t homedir-ai-sdlc:local \
  .

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Image built successfully${NC}"
else
  echo -e "${RED}ERROR: Image build failed${NC}"
  exit 1
fi

# Verify image
echo ""
echo -e "${GREEN}Verifying image...${NC}"
${CONTAINER_CMD} images | grep homedir-ai-sdlc

# Make scripts executable
chmod +x "${SCRIPT_DIR}/local-run-worker.sh"
chmod +x "${SCRIPT_DIR}/local-mark-issue.sh"
echo "✓ Scripts are executable"

# Summary
echo ""
echo -e "${BLUE}=== Setup Complete ===${NC}"
echo ""
echo "Next steps:"
echo "  1. Mark an issue: ./local-mark-issue.sh <issue-number>"
echo "  2. Run worker: ./local-run-worker.sh"
echo ""
echo "Examples:"
echo "  ./local-mark-issue.sh 1305"
echo "  ./local-run-worker.sh"
echo ""
echo "Logs will be in: ${SCRIPT_DIR}/local-logs/worker.log"
echo "State will be in: ${SCRIPT_DIR}/local-state/"
