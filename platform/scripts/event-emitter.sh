#!/bin/bash
# AI-SDLC Event Emitter
# Emits structured events for traceability and monitoring

set -euo pipefail

# Event queue directories
EVENT_QUEUE_DIR="${HOMEDIR_SDLC_STATE_DIR:-/var/lib/homedir-sdlc}/events"
DETECTION_QUEUE="${EVENT_QUEUE_DIR}/detection"
ADMISSION_QUEUE="${EVENT_QUEUE_DIR}/admission"
IMPLEMENTATION_QUEUE="${EVENT_QUEUE_DIR}/implementation"
PR_QUEUE="${EVENT_QUEUE_DIR}/pr"
CI_QUEUE="${EVENT_QUEUE_DIR}/ci"
REMEDIATION_QUEUE="${EVENT_QUEUE_DIR}/remediation"
DEPLOYMENT_QUEUE="${EVENT_QUEUE_DIR}/deployment"
ERROR_QUEUE="${EVENT_QUEUE_DIR}/errors"
HEARTBEAT_QUEUE="${EVENT_QUEUE_DIR}/heartbeat"

# All events stream (append-only log)
ALL_EVENTS_STREAM="${EVENT_QUEUE_DIR}/all-events.jsonl"

# Tracking state file
TRACKING_STATE="${EVENT_QUEUE_DIR}/tracking-state.json"

# Initialize event queues
init_event_system() {
  mkdir -p "$EVENT_QUEUE_DIR"
  mkdir -p "$DETECTION_QUEUE"
  mkdir -p "$ADMISSION_QUEUE"
  mkdir -p "$IMPLEMENTATION_QUEUE"
  mkdir -p "$PR_QUEUE"
  mkdir -p "$CI_QUEUE"
  mkdir -p "$REMEDIATION_QUEUE"
  mkdir -p "$DEPLOYMENT_QUEUE"
  mkdir -p "$ERROR_QUEUE"
  mkdir -p "$HEARTBEAT_QUEUE"

  touch "$ALL_EVENTS_STREAM"

  if [[ ! -f "$TRACKING_STATE" ]]; then
    echo '{}' > "$TRACKING_STATE"
  fi
}

# Generate UUID v4 (simple bash implementation)
generate_uuid() {
  cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || \
    printf '%08x-%04x-%04x-%04x-%012x' \
      $RANDOM$RANDOM $RANDOM $RANDOM $RANDOM $RANDOM$RANDOM$RANDOM
}

# Generate tracking ID for an issue
get_tracking_id() {
  local issue_number="$1"
  local timestamp
  timestamp=$(date -u +%Y%m%d%H%M%S)

  # Check if tracking ID already exists for this issue
  if [[ -f "$TRACKING_STATE" ]]; then
    local existing
    existing=$(jq -r ".\"$issue_number\" // empty" "$TRACKING_STATE")
    if [[ -n "$existing" ]]; then
      echo "$existing"
      return
    fi
  fi

  # Create new tracking ID
  local tracking_id="track_${issue_number}_${timestamp}"

  # Store in tracking state
  jq --arg issue "$issue_number" --arg track "$tracking_id" \
    '.[$issue] = $track' "$TRACKING_STATE" > "${TRACKING_STATE}.tmp"
  mv "${TRACKING_STATE}.tmp" "$TRACKING_STATE"

  echo "$tracking_id"
}

# Emit event
# Usage: emit_event <event_type> <issue_number> <status> [pr_number] [metadata_json]
emit_event() {
  local event_type="$1"
  local issue_number="$2"
  local status="$3"
  local pr_number="${4:-}"
  local metadata_json="${5:-{}}"

  # Generate IDs
  local event_id="evt_$(generate_uuid)"
  local tracking_id
  tracking_id=$(get_tracking_id "$issue_number")
  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%S%z)
  local action_timestamp
  action_timestamp=$(date -u +%Y%m%d%H%M%S)

  # Extract action type from event type
  local action_type
  action_type=$(echo "$event_type" | tr '.' '_')
  local action_id="act_${action_type}_${action_timestamp}"

  # Determine stage from event type
  local stage
  case "$event_type" in
    issue.detected)
      stage="detection"
      ;;
    admission.*)
      stage="admission"
      ;;
    implementation.*)
      stage="implementation"
      ;;
    pr.*)
      stage="pr_management"
      ;;
    ci.*)
      stage="ci_checks"
      ;;
    remediation.*)
      stage="remediation"
      ;;
    deployment.*)
      stage="deployment"
      ;;
    error.*)
      stage="error"
      ;;
    *)
      stage="unknown"
      ;;
  esac

  # Add worker version and repo to metadata
  local enhanced_metadata
  enhanced_metadata=$(echo "$metadata_json" | jq \
    --arg version "${HOMEDIR_SDLC_WORKER_VERSION:-unknown}" \
    --arg repo "${HOMEDIR_SDLC_REPO:-unknown}" \
    '. + {worker_version: $version, repository: $repo}')

  # Build event JSON
  local event_json
  event_json=$(jq -n \
    --arg event_id "$event_id" \
    --arg tracking_id "$tracking_id" \
    --arg action_id "$action_id" \
    --arg event_type "$event_type" \
    --arg timestamp "$timestamp" \
    --argjson issue_number "$issue_number" \
    --arg status "$status" \
    --arg stage "$stage" \
    --argjson metadata "$enhanced_metadata" \
    '{
      event_id: $event_id,
      tracking_id: $tracking_id,
      action_id: $action_id,
      event_type: $event_type,
      timestamp: $timestamp,
      issue_number: ($issue_number | tonumber),
      status: $status,
      stage: $stage,
      metadata: $metadata
    }')

  # Add PR number if provided
  if [[ -n "$pr_number" ]]; then
    event_json=$(echo "$event_json" | jq --argjson pr "$pr_number" '. + {pr_number: ($pr | tonumber)}')
  fi

  # Determine target queue
  local target_queue
  case "$stage" in
    detection) target_queue="$DETECTION_QUEUE" ;;
    admission) target_queue="$ADMISSION_QUEUE" ;;
    implementation) target_queue="$IMPLEMENTATION_QUEUE" ;;
    pr_management) target_queue="$PR_QUEUE" ;;
    ci_checks) target_queue="$CI_QUEUE" ;;
    remediation) target_queue="$REMEDIATION_QUEUE" ;;
    deployment) target_queue="$DEPLOYMENT_QUEUE" ;;
    error) target_queue="$ERROR_QUEUE" ;;
    *) target_queue="$EVENT_QUEUE_DIR" ;;
  esac

  # Write to stage-specific queue
  local queue_file="${target_queue}/${tracking_id}.jsonl"
  echo "$event_json" >> "$queue_file"

  # Write to all-events stream
  echo "$event_json" >> "$ALL_EVENTS_STREAM"

  # Emit to stdout for logging
  echo "[EVENT] $event_type | Issue #$issue_number | Status: $status | Event ID: $event_id" >&2

  # Return event_id for chaining
  echo "$event_id"
}

# Convenience functions for common events

emit_issue_detected() {
  local issue_number="$1"
  local metadata="${2:-{}}"
  emit_event "issue.detected" "$issue_number" "completed" "" "$metadata"
}

emit_issue_claimed() {
  local issue_number="$1"
  local metadata="${2:-{}}"
  emit_event "issue.claimed" "$issue_number" "completed" "" "$metadata"
}

emit_admission_started() {
  local issue_number="$1"
  emit_event "admission.started" "$issue_number" "in_progress" ""
}

emit_admission_completed() {
  local issue_number="$1"
  local decision="$2"  # ACCEPT or REJECT
  local reason="$3"
  local metadata
  metadata=$(jq -n --arg decision "$decision" --arg reason "$reason" '{decision: $decision, reason: $reason}')
  emit_event "admission.completed" "$issue_number" "completed" "" "$metadata"
}

emit_implementation_started() {
  local issue_number="$1"
  emit_event "implementation.started" "$issue_number" "in_progress" ""
}

emit_implementation_completed() {
  local issue_number="$1"
  local duration_ms="$2"
  local files_changed="${3:-0}"
  local metadata
  metadata=$(jq -n --argjson duration "$duration_ms" --argjson files "$files_changed" \
    '{duration_ms: $duration, files_changed: $files}')
  emit_event "implementation.completed" "$issue_number" "completed" "" "$metadata"
}

emit_pr_created() {
  local issue_number="$1"
  local pr_number="$2"
  local pr_url="$3"
  local metadata
  metadata=$(jq -n --arg url "$pr_url" '{pr_url: $url}')
  emit_event "pr.created" "$issue_number" "completed" "$pr_number" "$metadata"
}

emit_pr_merged() {
  local issue_number="$1"
  local pr_number="$2"
  local commit_sha="$3"
  local metadata
  metadata=$(jq -n --arg sha "$commit_sha" '{commit_sha: $sha}')
  emit_event "pr.merged" "$issue_number" "completed" "$pr_number" "$metadata"
}

emit_ci_check_started() {
  local issue_number="$1"
  local pr_number="$2"
  local check_name="$3"
  local metadata
  metadata=$(jq -n --arg check "$check_name" '{check_name: $check}')
  emit_event "ci.check.started" "$issue_number" "in_progress" "$pr_number" "$metadata"
}

emit_ci_check_failed() {
  local issue_number="$1"
  local pr_number="$2"
  local check_name="$3"
  local error_msg="$4"
  local metadata
  metadata=$(jq -n --arg check "$check_name" --arg error "$error_msg" \
    '{check_name: $check, error_message: $error}')
  emit_event "ci.check.failed" "$issue_number" "failed" "$pr_number" "$metadata"
}

emit_error() {
  local issue_number="$1"
  local error_msg="$2"
  local metadata
  metadata=$(jq -n --arg error "$error_msg" '{error_message: $error}')
  emit_event "error.occurred" "$issue_number" "failed" "" "$metadata"
}

emit_heartbeat() {
  local metadata
  metadata=$(jq -n --arg version "${HOMEDIR_SDLC_WORKER_VERSION:-unknown}" \
    '{worker_version: $version}')
  # Use issue 0 for system-level events
  emit_event "worker.heartbeat" "0" "completed" "" "$metadata"
}

# Query functions

# Get all events for a tracking ID
get_events_by_tracking_id() {
  local tracking_id="$1"

  # Search across all queue directories
  find "$EVENT_QUEUE_DIR" -name "${tracking_id}.jsonl" -type f -exec cat {} \; 2>/dev/null || echo "[]"
}

# Get latest N events
get_latest_events() {
  local limit="${1:-100}"

  if [[ -f "$ALL_EVENTS_STREAM" ]]; then
    tail -n "$limit" "$ALL_EVENTS_STREAM" | jq -s '.'
  else
    echo "[]"
  fi
}

# Get events by stage
get_events_by_stage() {
  local stage="$1"
  local limit="${2:-100}"

  local queue_dir
  case "$stage" in
    detection) queue_dir="$DETECTION_QUEUE" ;;
    admission) queue_dir="$ADMISSION_QUEUE" ;;
    implementation) queue_dir="$IMPLEMENTATION_QUEUE" ;;
    pr_management) queue_dir="$PR_QUEUE" ;;
    ci_checks) queue_dir="$CI_QUEUE" ;;
    remediation) queue_dir="$REMEDIATION_QUEUE" ;;
    deployment) queue_dir="$DEPLOYMENT_QUEUE" ;;
    error) queue_dir="$ERROR_QUEUE" ;;
    *) echo "[]"; return ;;
  esac

  find "$queue_dir" -name "*.jsonl" -type f -exec cat {} \; 2>/dev/null | tail -n "$limit" | jq -s '.'
}

# Get tracking ID for issue number
get_tracking_id_for_issue() {
  local issue_number="$1"

  if [[ -f "$TRACKING_STATE" ]]; then
    jq -r ".\"$issue_number\" // empty" "$TRACKING_STATE"
  fi
}

# Export functions
export -f init_event_system
export -f emit_event
export -f emit_issue_detected
export -f emit_issue_claimed
export -f emit_admission_started
export -f emit_admission_completed
export -f emit_implementation_started
export -f emit_implementation_completed
export -f emit_pr_created
export -f emit_pr_merged
export -f emit_ci_check_started
export -f emit_ci_check_failed
export -f emit_error
export -f emit_heartbeat
export -f get_events_by_tracking_id
export -f get_latest_events
export -f get_events_by_stage
export -f get_tracking_id_for_issue
