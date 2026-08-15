#!/bin/bash
# Script de verificación del worker en VPS
# Ejecutar: ssh homedir-sdlc@72.60.141.165 'bash -s' < verify-worker-vps.sh

set -e

echo "========================================"
echo "AI-SDLC Worker Verification"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "========================================"
echo ""

echo "1. POD STATUS"
echo "-------------"
podman pod ps | grep ai-sdlc || echo "Pod not found"
echo ""

echo "2. CONTAINERS"
echo "-------------"
podman ps --filter "pod=ai-sdlc" --format "{{.Names}}: {{.Status}}"
echo ""

echo "3. SCC VERSION"
echo "-------------"
podman exec ai-sdlc-worker scc --version || echo "SCC not available"
echo ""

echo "4. GITHUB AUTH TEST"
echo "-------------------"
if podman exec ai-sdlc-worker gh api user --jq '{login, name}' 2>/dev/null; then
  echo "✅ GitHub API access OK"
else
  echo "❌ GitHub API access FAILED"
  echo "Testing gh auth status:"
  podman exec ai-sdlc-worker gh auth status 2>&1 | head -5
fi
echo ""

echo "5. ENVIRONMENT VARIABLES"
echo "------------------------"
podman exec ai-sdlc-worker env | grep -E '^HOMEDIR_SDLC_TRIGGER_LABEL=' || echo "TRIGGER_LABEL not set"
podman exec ai-sdlc-worker env | grep -E '^HOMEDIR_SDLC_REPO=' || echo "REPO not set"
echo "GH_TOKEN: $(podman exec ai-sdlc-worker bash -c 'if [ -n "$GH_TOKEN" ]; then echo "SET (${#GH_TOKEN} chars)"; else echo "NOT SET"; fi')"
echo "SC_API_KEY: $(podman exec ai-sdlc-worker bash -c 'if [ -n "$SC_API_KEY" ]; then echo "SET (${#SC_API_KEY} chars)"; else echo "NOT SET"; fi')"
echo ""

echo "6. QUERY READY-TO-IMPLEMENT ISSUES"
echo "-----------------------------------"
if podman exec ai-sdlc-worker gh issue list --repo os-santiago/homedir --label ready-to-implement --limit 3 --json number,title 2>&1; then
  echo "✅ Issue query OK"
else
  echo "❌ Issue query FAILED"
fi
echo ""

echo "7. WORKER LOGS (last 30 lines)"
echo "-------------------------------"
podman logs --tail 30 ai-sdlc-worker 2>&1
echo ""

echo "8. HEARTBEAT"
echo "------------"
if [ -f /var/lib/homedir-sdlc/heartbeat.json ]; then
  cat /var/lib/homedir-sdlc/heartbeat.json | jq '{status, updated_at, detail}' 2>/dev/null || cat /var/lib/homedir-sdlc/heartbeat.json
else
  echo "Heartbeat file not found"
fi
echo ""

echo "========================================"
echo "Verification Complete"
echo "========================================"
