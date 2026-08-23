#!/bin/bash
# Watch a specific issue progress through enhanced admission
# Usage: bash watch-issue.sh 1389

ISSUE="${1:-1389}"
REPO="os-santiago/homedir"
VPS_HOST="72.60.141.165"
SSH_KEY="/home/scanales/.ssh/id_ed25519"

clear
echo "👁️  Watching Issue #${ISSUE}"
echo "=========================================="
echo "Press Ctrl+C to stop"
echo ""

while true; do
  clear
  echo "👁️  Issue #${ISSUE} - $(date '+%H:%M:%S')"
  echo "=========================================="
  echo ""

  # Get issue labels
  LABELS=$(gh issue view ${ISSUE} --repo ${REPO} --json labels --jq '[.labels[].name] | join(", ")')
  echo "📌 Labels:"
  echo "  $LABELS"
  echo ""

  # Get last comment
  LAST_COMMENT=$(gh issue view ${ISSUE} --repo ${REPO} --json comments --jq '.comments[-1] | {
    author: .author.login,
    time: .createdAt,
    preview: (.body | split("\n") | .[0:3] | join("\n"))
  }')

  echo "💬 Last Comment:"
  echo "$LAST_COMMENT" | jq -r '"  By: \(.author) at \(.time)\n  \(.preview)"'
  echo ""

  # Check worker logs for this issue
  if command -v wsl.exe >/dev/null 2>&1; then
    WORKER_LOGS=$(wsl bash -c "ssh -i ${SSH_KEY} root@${VPS_HOST} 'podman logs --tail 50 ai-sdlc-worker 2>&1 | grep \"issue #${ISSUE}\" | tail -5'" 2>/dev/null || echo "")
  else
    WORKER_LOGS=$(ssh -i "${SSH_KEY}" "root@${VPS_HOST}" "podman logs --tail 50 ai-sdlc-worker 2>&1 | grep 'issue #${ISSUE}' | tail -5" 2>/dev/null || echo "")
  fi

  if [[ -n "$WORKER_LOGS" ]]; then
    echo "🤖 Worker Logs (last 5 mentions):"
    echo "$WORKER_LOGS" | while IFS= read -r line; do
      echo "  $(echo "$line" | cut -c1-120)"
    done
  else
    echo "🤖 Worker: No recent activity for this issue"
  fi

  echo ""
  echo "=========================================="

  # State detection
  if echo "$LABELS" | grep -q "scc-parent"; then
    echo "✅ STATE: Parent created (fragmentation)"
    if echo "$LABELS" | grep -q "scc-fragmentation-approved"; then
      echo "   Children executing..."
    else
      echo "   ⏳ WAITING: Add label 'scc-fragmentation-approved'"
    fi
  elif echo "$LABELS" | grep -q "scc-enriched"; then
    echo "✅ STATE: Enriched"
    if echo "$LABELS" | grep -q "scc-enrichment-approved"; then
      echo "   Approved, proceeding to implementation"
    else
      echo "   ⏳ WAITING: Add label 'scc-enrichment-approved'"
    fi
  elif echo "$LABELS" | grep -q "scc-queued"; then
    echo "🔄 STATE: Queued for implementation"
  elif echo "$LABELS" | grep -q "scc-running"; then
    echo "⚙️  STATE: SCC executing"
  elif echo "$LABELS" | grep -q "ready-to-implement"; then
    echo "⏳ STATE: Waiting for worker cycle"
  else
    echo "❓ STATE: Unknown"
  fi

  echo ""
  echo "Refreshing in 15s..."
  sleep 15
done
