#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== AI-SDLC Local Worker ===${NC}"

# Check environment
if [[ -z "${GH_TOKEN}" ]]; then
  echo -e "${RED}ERROR: GH_TOKEN not set${NC}"
  exit 1
fi

if [[ -z "${SC_API_KEY}" ]]; then
  echo -e "${YELLOW}WARNING: SC_API_KEY not set (SCC won't work)${NC}"
fi

# Prepare state
mkdir -p "${SCRIPT_DIR}/local-state"/{issues,prs,run-summaries,autonomous-decisions}
mkdir -p "${SCRIPT_DIR}/local-logs"

# Create env file
cat > "${SCRIPT_DIR}/local-state/runtime.env" <<EOF
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_LOGFILE=/var/log/homedir-sdlc/worker.log
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_WORKER_VERSION=local-dev
GH_TOKEN=${GH_TOKEN}
SC_API_KEY=${SC_API_KEY:-}
PLATFORM_DIR=/app
EOF

echo -e "${GREEN}Running worker container...${NC}"

# Detect container runtime
if command -v podman &> /dev/null; then
  CONTAINER_CMD="podman"
  SELINUX_OPT=":Z"
elif command -v docker &> /dev/null; then
  CONTAINER_CMD="docker"
  SELINUX_OPT=""
else
  echo -e "${RED}ERROR: Neither podman nor docker found${NC}"
  exit 1
fi

# Run container
${CONTAINER_CMD} run --rm \
  --user $(id -u):$(id -g) \
  -e HOME=/tmp \
  --env-file "${SCRIPT_DIR}/local-state/runtime.env" \
  -v "${SCRIPT_DIR}/local-state:/var/lib/homedir-sdlc${SELINUX_OPT}" \
  -v "${SCRIPT_DIR}/local-logs:/var/log/homedir-sdlc${SELINUX_OPT}" \
  homedir-ai-sdlc:local \
  reconcile

EXIT_CODE=$?

echo ""
echo -e "${GREEN}=== Worker Complete ===${NC}"
echo "Exit code: ${EXIT_CODE}"

# Show logs
if [[ -f "${SCRIPT_DIR}/local-logs/worker.log" ]]; then
  echo ""
  echo -e "${GREEN}=== Last 30 Lines of Log ===${NC}"
  tail -30 "${SCRIPT_DIR}/local-logs/worker.log"
fi

# Show state
echo ""
echo -e "${GREEN}=== State Directory ===${NC}"
find "${SCRIPT_DIR}/local-state" -type f -mmin -5 2>/dev/null | head -10

exit ${EXIT_CODE}
