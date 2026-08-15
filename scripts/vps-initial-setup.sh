#!/bin/bash
#
# VPS Initial Setup Script for AI-SDLC Containerized Deployment
#
# This script prepares a fresh VPS for AI-SDLC deployment.
# Run once as root during initial setup.
#
# Usage: bash vps-initial-setup.sh
#

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  AI-SDLC VPS Initial Setup                                 ║"
echo "║  Containerized Deployment with Podman                      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "❌ ERROR: This script must be run as root"
  echo "   Try: sudo bash $0"
  exit 1
fi

echo "✓ Running as root"
echo ""

# Step 1: Install Podman
echo "═══ Step 1: Installing Podman ═══"
if command -v podman &> /dev/null; then
  echo "✓ Podman already installed: $(podman --version)"
else
  echo "Installing Podman..."
  apt-get update
  apt-get install -y podman
  echo "✓ Podman installed: $(podman --version)"
fi
echo ""

# Step 2: Install required tools
echo "═══ Step 2: Installing required tools ═══"
apt-get install -y \
  curl \
  jq \
  git \
  ca-certificates

echo "✓ Tools installed"
echo ""

# Step 3: Create directory structure
echo "═══ Step 3: Creating directory structure ═══"

# State directory (worker writes here)
mkdir -p /var/lib/homedir-sdlc/{logs,issues,prs,run-summaries}
echo "✓ Created /var/lib/homedir-sdlc"

# Worktrees directory (git checkouts)
mkdir -p /srv/homedir-sdlc/worktrees
echo "✓ Created /srv/homedir-sdlc/worktrees"

# Config directory (env files, secrets)
mkdir -p /etc/homedir-sdlc
echo "✓ Created /etc/homedir-sdlc"

# Set permissions
chmod 755 /var/lib/homedir-sdlc
chmod 755 /srv/homedir-sdlc
chmod 755 /etc/homedir-sdlc
echo "✓ Permissions set"
echo ""

# Step 4: Create environment file template
echo "═══ Step 4: Creating environment file template ═══"

if [ -f /etc/homedir-sdlc/worker.env ]; then
  echo "⚠️  /etc/homedir-sdlc/worker.env already exists"
  echo "   Backing up to /etc/homedir-sdlc/worker.env.backup"
  cp /etc/homedir-sdlc/worker.env /etc/homedir-sdlc/worker.env.backup
fi

cat > /etc/homedir-sdlc/worker.env << 'EOF'
# AI-SDLC Worker Environment Configuration
# Edit this file and replace placeholder values with actual secrets

# ============================================================================
# GitHub Configuration
# ============================================================================
# Create token at: https://github.com/settings/tokens
# Required scopes: repo, workflow
GH_TOKEN=REPLACE_WITH_YOUR_GITHUB_TOKEN

# Repository to process issues from
HOMEDIR_SDLC_REPO=os-santiago/homedir

# ============================================================================
# SCC (Claude Code) Configuration
# ============================================================================
# SCC profile to use (nvidia, anthropic, openai, etc.)
HOMEDIR_SDLC_SCC_PROFILE=nvidia

# Maximum iterations per SCC run
SC_MAX_ITERATIONS=10

# API key for the SCC profile
# For NVIDIA: Get from https://build.nvidia.com/
SC_API_KEY=REPLACE_WITH_YOUR_NVIDIA_API_KEY

# SCC permissions
HOMEDIR_SDLC_SCC_PERMISSIONS=unlimited
HOMEDIR_SDLC_SCC_CLEAR_HISTORY=true

# ============================================================================
# State and Logging Configuration
# ============================================================================
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_LOGFILE=/var/lib/homedir-sdlc/logs/worker.log
HOMEDIR_SDLC_HEARTBEAT_FILE=/var/lib/homedir-sdlc/heartbeat.json

# ============================================================================
# Worker Configuration
# ============================================================================
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_MAX_ISSUES_PER_RUN=1
HOMEDIR_SDLC_MAX_REMEDIATION_ATTEMPTS=5
HOMEDIR_SDLC_PR_REVIEW_DELAY_SECONDS=600
HOMEDIR_SDLC_ENABLE_AUTOMERGE=false

# ============================================================================
# Labels Configuration
# ============================================================================
HOMEDIR_SDLC_TRIGGER_LABEL=ready-to-implement
HOMEDIR_SDLC_QUEUE_LABEL=scc-queued
HOMEDIR_SDLC_REJECTED_LABEL=scc-rejected
HOMEDIR_SDLC_AUTHORIZED_LABELERS=scanalesespinoza
HOMEDIR_SDLC_ADMISSION_REVIEW_LABEL=scc-admission-review
HOMEDIR_SDLC_ACCEPTED_LABEL=scc-accepted
HOMEDIR_SDLC_RUNNING_LABEL=scc-running
HOMEDIR_SDLC_PR_LABEL=scc-pr-open
HOMEDIR_SDLC_WAITING_CHECKS_LABEL=scc-waiting-checks
HOMEDIR_SDLC_FAILING_CHECKS_LABEL=scc-failing-checks
HOMEDIR_SDLC_UNDER_REVIEW_LABEL=scc-under-review
HOMEDIR_SDLC_APPROVED_LABEL=scc-approved
HOMEDIR_SDLC_FAILED_LABEL=scc-failed
HOMEDIR_SDLC_NEEDS_HUMAN_LABEL=needs-human
HOMEDIR_SDLC_MERGED_LABEL=scc-merged

# ============================================================================
# Logging
# ============================================================================
HOMEDIR_SDLC_LOG_LEVEL=INFO

# ============================================================================
# Git Configuration
# ============================================================================
HOMEDIR_SDLC_GIT_USER_NAME=homedir-sdlc[bot]
HOMEDIR_SDLC_GIT_USER_EMAIL=homedir-sdlc@users.noreply.github.com
EOF

chmod 600 /etc/homedir-sdlc/worker.env
echo "✓ Created /etc/homedir-sdlc/worker.env (mode 600)"
echo ""

# Step 5: Login to GitHub Container Registry
echo "═══ Step 5: Container Registry Setup ═══"
echo "Public images from ghcr.io/os-santiago/homedir-ai-sdlc"
echo "No authentication required for pulling"
echo "✓ Registry ready"
echo ""

# Step 6: Test Podman
echo "═══ Step 6: Testing Podman ═══"
podman info | grep -A 2 "version:"
echo "✓ Podman is working"
echo ""

# Step 7: Create verification script
echo "═══ Step 7: Creating verification script ═══"
cat > /usr/local/bin/verify-ai-sdlc << 'VERIFYEOF'
#!/bin/bash
# Verify AI-SDLC deployment health

echo "=== AI-SDLC Health Check ==="
echo ""

# Check pod
echo "1. Pod status:"
podman pod ps | grep ai-sdlc || echo "   ❌ Pod not running"
echo ""

# Check containers
echo "2. Container status:"
podman ps --filter name=ai-sdlc
echo ""

# Check heartbeat
echo "3. Worker heartbeat:"
if [ -f /var/lib/homedir-sdlc/heartbeat.json ]; then
  cat /var/lib/homedir-sdlc/heartbeat.json | jq '.'

  # Check age
  age=$(python3 -c "import json, time; h=json.load(open('/var/lib/homedir-sdlc/heartbeat.json')); print(int(time.time() - time.mktime(time.strptime(h['updated_at'], '%Y-%m-%dT%H:%M:%SZ'))))")
  echo "   Age: ${age}s"

  if [ $age -gt 300 ]; then
    echo "   ⚠️  WARNING: Heartbeat is stale (>5 min)"
  else
    echo "   ✅ Heartbeat is fresh"
  fi
else
  echo "   ❌ Heartbeat file not found"
fi
echo ""

# Check dashboard
echo "4. Dashboard health:"
curl -sf http://localhost:8081/q/health/live > /dev/null && echo "   ✅ Dashboard healthy" || echo "   ❌ Dashboard not responding"
echo ""

# Check logs (errors)
echo "5. Recent errors in worker logs:"
error_count=$(podman logs --tail 100 ai-sdlc-worker 2>&1 | grep -i error | wc -l)
echo "   Error count (last 100 lines): $error_count"
if [ $error_count -gt 0 ]; then
  echo "   Last 3 errors:"
  podman logs --tail 100 ai-sdlc-worker 2>&1 | grep -i error | tail -3
fi
VERIFYEOF

chmod +x /usr/local/bin/verify-ai-sdlc
echo "✓ Created /usr/local/bin/verify-ai-sdlc"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  ✅ Initial Setup Complete                                 ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit environment file with your secrets:"
echo "   vim /etc/homedir-sdlc/worker.env"
echo ""
echo "2. Replace these placeholders:"
echo "   - GH_TOKEN: Your GitHub personal access token"
echo "   - SC_API_KEY: Your NVIDIA API key (or other provider)"
echo ""
echo "3. Deploy AI-SDLC:"
echo "   - Option A: Push to main branch (triggers CI/CD)"
echo "   - Option B: Manual deployment (see docs/deployment/containerized-deployment.md)"
echo ""
echo "4. Verify deployment:"
echo "   verify-ai-sdlc"
echo ""
echo "Documentation:"
echo "  https://github.com/os-santiago/homedir-ai-sdlc/blob/main/docs/deployment/containerized-deployment.md"
echo ""
