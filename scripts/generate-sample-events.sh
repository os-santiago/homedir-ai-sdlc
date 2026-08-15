#!/bin/bash
# Generate Sample Events - For testing dashboard without full worker execution
# Creates realistic event data to populate the dashboard

set -euo pipefail

# Setup test environment
export HOMEDIR_SDLC_STATE_DIR="${HOMEDIR_SDLC_STATE_DIR:-./local-state}"
export HOMEDIR_SDLC_WORKER_VERSION="v2.5.0-dev"
export HOMEDIR_SDLC_REPO="os-santiago/homedir"

# Source event emitter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../platform/scripts/event-emitter.sh"

# Initialize
init_event_system

echo "Generating sample events..."
echo ""

# Simulate 3 different issue lifecycles

# ============================================================================
# Issue 1360: Completed successfully (full lifecycle)
# ============================================================================
echo "Issue #1360: Full successful lifecycle"

emit_issue_detected 1360 '{"title": "Bug: notifications_center_empty_cta_board", "labels": ["bug"]}'
sleep 1

emit_issue_claimed 1360
sleep 1

emit_admission_started 1360
sleep 2

emit_admission_completed 1360 "ACCEPT" "Meets all criteria: has label bug, no PR exists, clear description"
sleep 1

emit_implementation_started 1360
sleep 8

emit_implementation_completed 1360 8234 3
sleep 1

emit_pr_created 1360 1450 "https://github.com/os-santiago/homedir/pull/1450"
sleep 2

emit_event "ci.check.started" 1360 "in_progress" 1450 '{"check_name": "test-suite"}'
sleep 3

emit_event "ci.check.passed" 1360 "completed" 1450 '{"check_name": "test-suite"}'
sleep 1

emit_event "ci.check.started" 1360 "in_progress" 1450 '{"check_name": "build"}'
sleep 2

emit_event "ci.check.passed" 1360 "completed" 1450 '{"check_name": "build"}'
sleep 1

emit_pr_merged 1360 1450 "abc123def456"
sleep 1

emit_event "deployment.started" 1360 "in_progress" 1450 '{"environment": "production"}'
sleep 3

emit_event "deployment.completed" 1360 "completed" 1450 '{"environment": "production", "duration_ms": 3200}'

echo "  ✓ Issue #1360: Complete (MERGED)"
echo ""

# ============================================================================
# Issue 1361: In progress (implementation stage)
# ============================================================================
echo "Issue #1361: Currently implementing"

emit_issue_detected 1361 '{"title": "Feature: Add dark mode toggle", "labels": ["enhancement"]}'
sleep 1

emit_issue_claimed 1361
sleep 1

emit_admission_started 1361
sleep 1

emit_admission_completed 1361 "ACCEPT" "Feature request approved"
sleep 1

emit_implementation_started 1361

echo "  ⏳ Issue #1361: In progress (IMPLEMENTING)"
echo ""

# ============================================================================
# Issue 1362: Failed at CI stage
# ============================================================================
echo "Issue #1362: CI failure scenario"

emit_issue_detected 1362 '{"title": "Bug: Form validation not working", "labels": ["bug"]}'
sleep 1

emit_issue_claimed 1362
sleep 1

emit_admission_started 1362
sleep 1

emit_admission_completed 1362 "ACCEPT" "Valid bug report"
sleep 1

emit_implementation_started 1362
sleep 5

emit_implementation_completed 1362 5123 2
sleep 1

emit_pr_created 1362 1451 "https://github.com/os-santiago/homedir/pull/1451"
sleep 1

emit_event "ci.check.started" 1362 "in_progress" 1451 '{"check_name": "test-suite"}'
sleep 2

emit_ci_check_failed 1362 1451 "test-suite" "3 tests failed: test_form_validation, test_submit_handler, test_error_display"
sleep 1

emit_event "remediation.started" 1362 "in_progress" 1451 '{"attempt": 1}'

echo "  ⚠ Issue #1362: CI failed (REMEDIATION)"
echo ""

# ============================================================================
# Issue 1363: Rejected at admission
# ============================================================================
echo "Issue #1363: Rejected scenario"

emit_issue_detected 1363 '{"title": "Question: How to configure X?", "labels": ["question"]}'
sleep 1

emit_issue_claimed 1363
sleep 1

emit_admission_started 1363
sleep 1

emit_admission_completed 1363 "REJECT" "Not a bug or feature request - question type issues not processed"

echo "  ✗ Issue #1363: Rejected (ADMISSION)"
echo ""

# ============================================================================
# Issue 1364: Just detected
# ============================================================================
echo "Issue #1364: Just queued"

emit_issue_detected 1364 '{"title": "Bug: Memory leak in worker process", "labels": ["bug", "performance"]}'

echo "  ○ Issue #1364: Queued (DETECTION)"
echo ""

# ============================================================================
# Heartbeats (simulating worker running)
# ============================================================================
echo "Adding heartbeat events..."

for i in {1..5}; do
  emit_heartbeat > /dev/null
  sleep 1
done

echo "  ✓ 5 heartbeats added"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Sample Events Generated Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Event Summary:"
TOTAL_EVENTS=$(wc -l < "${HOMEDIR_SDLC_STATE_DIR}/events/all-events.jsonl")
echo "  Total events: $TOTAL_EVENTS"
echo ""

echo "By type:"
jq -r '.event_type' "${HOMEDIR_SDLC_STATE_DIR}/events/all-events.jsonl" | sort | uniq -c | sort -rn
echo ""

echo "Active issues:"
echo "  #1361 - In progress (implementing)"
echo "  #1362 - CI failed (remediation)"
echo "  #1364 - Just detected"
echo ""

echo "Completed issues:"
echo "  #1360 - Fully deployed ✓"
echo ""

echo "Rejected issues:"
echo "  #1363 - Not eligible ✗"
echo ""

echo "Data location: ${HOMEDIR_SDLC_STATE_DIR}/events/"
echo ""

echo "Next steps:"
echo "  1. Start dashboard: cd dashboard/quarkus-app && ./mvnw quarkus:dev"
echo "  2. Visit: http://localhost:8081/sdlc/events/"
echo "  3. Try search: 1360, 1361, 1362"
echo ""
