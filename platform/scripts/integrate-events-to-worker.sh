#!/bin/bash
# Integration guide for adding event emission to homedir-sdlc-worker.sh
# This shows WHERE to add emit_event calls in the main worker script

# This is a REFERENCE file showing the integration points
# NOT to be executed directly

cat <<'EOF'
# ============================================================================
# Event Integration Points for homedir-sdlc-worker.sh
# ============================================================================

# At the START of the script (after sourcing config):

source "${PLATFORM_DIR}/scripts/event-emitter.sh"
init_event_system

# ============================================================================
# 1. Worker Heartbeat (in main reconcile loop)
# ============================================================================

reconcile() {
  emit_heartbeat

  # ... existing code ...
}

# ============================================================================
# 2. Issue Detection
# ============================================================================

# After finding ready-to-implement issues:

for issue in $(find_ready_to_implement_issues); do
  issue_number=$(echo "$issue" | jq -r '.number')

  emit_issue_detected "$issue_number" "$(echo "$issue" | jq -c '{title: .title, labels: .labels}')"

  # ... existing code ...
done

# ============================================================================
# 3. Issue Claimed
# ============================================================================

# After claiming an issue (adding scc-claimed label):

claim_issue() {
  local issue_number="$1"

  # ... existing claim logic ...

  emit_issue_claimed "$issue_number"
}

# ============================================================================
# 4. Admission Review
# ============================================================================

# Before admission review:

emit_admission_started "$issue_number"

# After admission review:

run_admission_review() {
  local issue_number="$1"

  # ... existing admission logic ...

  local decision="$DECISION"  # ACCEPT or REJECT
  local reason="$REASON"

  emit_admission_completed "$issue_number" "$decision" "$reason"
}

# ============================================================================
# 5. Implementation (SCC)
# ============================================================================

# Before SCC execution:

START_TIME=$(date +%s%3N)
emit_implementation_started "$issue_number"

# After SCC execution:

implement_with_scc() {
  local issue_number="$1"

  # ... existing SCC logic ...

  END_TIME=$(date +%s%3N)
  DURATION=$((END_TIME - START_TIME))
  FILES_CHANGED=$(git diff --name-only | wc -l)

  emit_implementation_completed "$issue_number" "$DURATION" "$FILES_CHANGED"
}

# ============================================================================
# 6. PR Creation
# ============================================================================

# After creating PR:

create_pr() {
  local issue_number="$1"

  # ... existing PR creation logic ...

  local pr_number="$PR_NUMBER"
  local pr_url="$PR_URL"

  emit_pr_created "$issue_number" "$pr_number" "$pr_url"
}

# ============================================================================
# 7. CI Checks
# ============================================================================

# When starting to monitor CI checks:

monitor_ci_checks() {
  local issue_number="$1"
  local pr_number="$2"

  emit_ci_check_started "$issue_number" "$pr_number" "all-checks"

  # ... existing CI monitoring ...

  if [[ "$CHECK_STATUS" == "failed" ]]; then
    emit_ci_check_failed "$issue_number" "$pr_number" "$CHECK_NAME" "$ERROR_MSG"
  else
    emit_event "ci.check.passed" "$issue_number" "completed" "$pr_number" \
      "$(jq -n --arg check "$CHECK_NAME" '{check_name: $check}')"
  fi
}

# ============================================================================
# 8. PR Merged
# ============================================================================

# After PR is merged:

on_pr_merged() {
  local issue_number="$1"
  local pr_number="$2"
  local commit_sha="$3"

  emit_pr_merged "$issue_number" "$pr_number" "$commit_sha"
}

# ============================================================================
# 9. Error Handling
# ============================================================================

# In error handlers:

handle_error() {
  local issue_number="$1"
  local error_msg="$2"

  emit_error "$issue_number" "$error_msg"

  # ... existing error handling ...
}

# ============================================================================
# 10. Deployment Tracking
# ============================================================================

# When deployment is detected:

emit_event "deployment.started" "$issue_number" "in_progress" "$pr_number"

# After deployment completes:

emit_event "deployment.completed" "$issue_number" "completed" "$pr_number" \
  "$(jq -n --arg env "production" '{environment: $env}')"

EOF
