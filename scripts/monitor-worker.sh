#!/bin/bash
# Quick worker monitoring script
# Usage: bash monitor-worker.sh

set -euo pipefail

VPS_HOST="${VPS_HOST:-72.60.141.165}"
SSH_KEY="${SSH_KEY:-/home/scanales/.ssh/id_ed25519}"

echo "🔍 AI-SDLC Worker Monitor"
echo "=========================================="
echo ""

# Check if running via WSL or native bash
if command -v wsl.exe >/dev/null 2>&1; then
  SSH_CMD="wsl bash -c \"ssh -i ${SSH_KEY} root@${VPS_HOST}\""
else
  SSH_CMD="ssh -i ${SSH_KEY} root@${VPS_HOST}"
fi

# Function to run SSH commands
run_ssh() {
  if command -v wsl.exe >/dev/null 2>&1; then
    wsl bash -c "ssh -i ${SSH_KEY} root@${VPS_HOST} '$1'"
  else
    ssh -i "${SSH_KEY}" "root@${VPS_HOST}" "$1"
  fi
}

# 1. Worker Status
echo "📦 Worker Container"
run_ssh "podman ps --filter name=ai-sdlc-worker --format 'Status: {{.Status}}'"
echo ""

# 2. Heartbeat
echo "💓 Heartbeat"
HEARTBEAT=$(run_ssh "cat /var/lib/homedir-sdlc/heartbeat.json")
echo "$HEARTBEAT" | jq '{
  status,
  detail,
  updated_at,
  worker_version: (.worker_version // "unknown" | .[0:7]),
  metrics: {
    autonomy_rate: .metrics.autonomy_rate,
    total_issues: .metrics.total_issues,
    total_prs: .metrics.total_prs
  }
}'
echo ""

# 3. Recent Worker Activity
echo "📋 Recent Worker Activity (last 20 lines)"
run_ssh "podman logs --tail 20 ai-sdlc-worker 2>&1 | grep -E '(issue #|reconcile|enhanced|ERROR|WARN)' || podman logs --tail 20 ai-sdlc-worker 2>&1"
echo ""

# 4. Issues Being Processed
echo "🎯 Issues with ready-to-implement"
run_ssh "gh issue list --repo os-santiago/homedir --label ready-to-implement --state open --limit 10 --json number,title,labels" | \
  jq -r '.[] | "  #\(.number): \(.title) [\([.labels[].name] | join(", "))]"'
echo ""

# 5. Active SDLC Labels
echo "🏷️  Active SDLC Issues"
for label in scc-queued scc-running scc-pr-created scc-enriched scc-parent; do
  COUNT=$(run_ssh "gh issue list --repo os-santiago/homedir --label $label --state open --json number" | jq '. | length')
  if [[ "$COUNT" -gt 0 ]]; then
    echo "  $label: $COUNT issues"
  fi
done
echo ""

echo "=========================================="
echo "✅ Monitor complete at $(date)"
