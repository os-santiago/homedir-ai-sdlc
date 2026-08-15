#!/bin/bash
set -e

ISSUE_NUMBER=$1

if [[ -z "${ISSUE_NUMBER}" ]]; then
  echo "Usage: $0 <issue-number>"
  exit 1
fi

if [[ -z "${GH_TOKEN}" ]]; then
  echo "ERROR: GH_TOKEN not set"
  exit 1
fi

echo "Marking issue #${ISSUE_NUMBER} for AI-SDLC..."

gh issue edit ${ISSUE_NUMBER} \
  -R os-santiago/homedir \
  --add-label "ready-to-implement"

echo "✅ Issue #${ISSUE_NUMBER} marked"
echo ""
echo "Now run: ./local-run-worker.sh"
