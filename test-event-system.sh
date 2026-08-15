#!/bin/bash
# Test Event System - Standalone Validation
# Tests event infrastructure without modifying worker

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=================================="
echo "AI-SDLC Event System Test"
echo "=================================="
echo ""

# Setup test environment
TEST_DIR="$(pwd)/test-events"
export HOMEDIR_SDLC_STATE_DIR="$TEST_DIR"

echo "Test directory: $TEST_DIR"
echo ""

# Clean previous test
rm -rf "$TEST_DIR"

# Source event emitter
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/platform/scripts/event-emitter.sh"

# Test 1: Initialization
echo -n "Test 1: Event system initialization... "
init_event_system

if [[ -d "$TEST_DIR/events" ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 2: Emit heartbeat
echo -n "Test 2: Emit heartbeat event... "
EVENT_ID=$(emit_heartbeat)

if [[ -n "$EVENT_ID" ]] && [[ "$EVENT_ID" =~ ^evt_ ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
  echo "   Event ID: $EVENT_ID"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 3: All-events stream
echo -n "Test 3: All-events stream created... "
if [[ -f "$TEST_DIR/events/all-events.jsonl" ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 4: Event JSON valid
echo -n "Test 4: Event JSON is valid... "
if jq empty "$TEST_DIR/events/all-events.jsonl" 2>/dev/null; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 5: Issue detection
echo -n "Test 5: Emit issue.detected... "
EVENT_ID=$(emit_issue_detected 999 '{"title": "Test issue"}')
if [[ "$EVENT_ID" =~ ^evt_ ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 6: Tracking ID
echo -n "Test 6: Tracking ID generated... "
TRACKING_ID=$(get_tracking_id_for_issue 999)
if [[ "$TRACKING_ID" =~ ^track_999_ ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
  echo "   Tracking ID: $TRACKING_ID"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 7: Stage queue
echo -n "Test 7: Detection queue created... "
if [[ -d "$TEST_DIR/events/detection" ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 8: Multiple event types
echo -n "Test 8: Multiple event types... "
emit_issue_claimed 999 > /dev/null
emit_admission_started 999 > /dev/null
emit_admission_completed 999 "ACCEPT" "Test approved" > /dev/null

EVENT_TYPES=$(jq -r '.event_type' "$TEST_DIR/events/all-events.jsonl" | sort -u)
if [[ $(echo "$EVENT_TYPES" | wc -l) -ge 4 ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
  echo "   Event types: $(echo "$EVENT_TYPES" | tr '\n' ', ')"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 9: Query by tracking ID
echo -n "Test 9: Query events by tracking ID... "
EVENTS=$(get_events_by_tracking_id "$TRACKING_ID")
EVENT_COUNT=$(echo "$EVENTS" | jq -s '.[0] | length' 2>/dev/null || echo 0)
if [[ $EVENT_COUNT -gt 0 ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
  echo "   Found $EVENT_COUNT events"
else
  echo -e "${RED}✗ FAIL${NC}"
  exit 1
fi

# Test 10: Event schema compliance
echo -n "Test 10: Event schema compliance... "
INVALID=$(jq 'select(.event_id == null or .tracking_id == null or .action_id == null or .timestamp == null)' \
  "$TEST_DIR/events/all-events.jsonl")
if [[ -z "$INVALID" ]]; then
  echo -e "${GREEN}✓ PASS${NC}"
else
  echo -e "${RED}✗ FAIL${NC}"
  echo "   Invalid events found:"
  echo "$INVALID"
  exit 1
fi

# Summary
echo ""
echo "=================================="
echo -e "${GREEN}All tests passed! ✓${NC}"
echo "=================================="
echo ""

echo "Sample event:"
jq '.' "$TEST_DIR/events/all-events.jsonl" | head -20

echo ""
echo "Event statistics:"
echo "  Total events: $(wc -l < "$TEST_DIR/events/all-events.jsonl")"
echo "  Event types: $(jq -r '.event_type' "$TEST_DIR/events/all-events.jsonl" | sort -u | wc -l)"
echo "  Stages: $(jq -r '.stage' "$TEST_DIR/events/all-events.jsonl" | sort -u | wc -l)"

echo ""
echo "Test directory: $TEST_DIR"
echo "To inspect: cat $TEST_DIR/events/all-events.jsonl | jq ."
echo ""
echo "Cleanup: rm -rf $TEST_DIR"
