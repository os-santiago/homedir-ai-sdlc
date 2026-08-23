#!/usr/bin/env bash
# Enhanced admission functions for AI-SDLC
# These functions implement SCC-based triage, enrichment, and fragmentation

# ============================================================================
# ENHANCED ADMISSION - SCC ANALYSIS FUNCTIONS
# ============================================================================

# Environment variables for enhanced admission
ENHANCED_ADMISSION_ENABLED="${HOMEDIR_SDLC_ENHANCED_ADMISSION:-true}"
SCC_ADMISSION_ANALYSIS_TIMEOUT="${SCC_ADMISSION_ANALYSIS_TIMEOUT:-120}"
SCC_ENRICHMENT_TIMEOUT="${SCC_ENRICHMENT_TIMEOUT:-300}"
SCC_FRAGMENTATION_TIMEOUT="${SCC_FRAGMENTATION_TIMEOUT:-600}"
SCC_VALIDATION_TIMEOUT="${SCC_VALIDATION_TIMEOUT:-120}"
MAX_CHILDREN_PER_PARENT="${MAX_CHILDREN_PER_PARENT:-10}"

# Enhanced admission labels
ENRICHED_LABEL="${HOMEDIR_SDLC_ENRICHED_LABEL:-scc-enriched}"
ENRICHMENT_APPROVED_LABEL="${HOMEDIR_SDLC_ENRICHMENT_APPROVED_LABEL:-scc-enrichment-approved}"
PARENT_LABEL="${HOMEDIR_SDLC_PARENT_LABEL:-scc-parent}"
CHILD_LABEL="${HOMEDIR_SDLC_CHILD_LABEL:-scc-child}"
FRAGMENTATION_LABEL="${HOMEDIR_SDLC_FRAGMENTATION_LABEL:-scc-fragmentation}"
FRAGMENTATION_APPROVED_LABEL="${HOMEDIR_SDLC_FRAGMENTATION_APPROVED_LABEL:-scc-fragmentation-approved}"
PARENT_EXECUTING_LABEL="${HOMEDIR_SDLC_PARENT_EXECUTING_LABEL:-scc-parent-executing}"
PARENT_VALIDATED_LABEL="${HOMEDIR_SDLC_PARENT_VALIDATED_LABEL:-scc-parent-validated}"

# Analyze issue quality and determine admission path
# Returns JSON: {"classification": "COMPLETE|INCOMPLETE|MULTI_CRITERIA|ERROR", ...}
analyze_issue_quality() {
  local issue_number="$1"
  local issue_body="$2"
  local issue_title="$3"

  log "analyze_issue_quality: analyzing issue #${issue_number}"

  local prompt="Analyze this GitHub issue for AI-SDLC admission.

Issue #${issue_number}: ${issue_title}

Body:
${issue_body}

Classify as ONE of:
1. COMPLETE - Has all required sections (Description, Current state, Desired state, Acceptance Criteria with 2+ items, Complexity, Priority, Type), criteria are specific, and is ATOMIC (single concern)
2. INCOMPLETE - Missing sections or vague criteria, but is ATOMIC
3. MULTI_CRITERIA - Multiple UNRELATED concerns (e.g. \"Fix login AND add dark mode AND update docs\" = 3 separate issues)
4. ERROR - Cannot process

Respond ONLY with JSON (no extra text):
{\"classification\":\"COMPLETE|INCOMPLETE|MULTI_CRITERIA|ERROR\",\"reasoning\":\"why\",\"missing_sections\":[],\"criteria_issues\":[],\"concerns\":[],\"confidence\":0.9}"

  local response
  local rc

  # Use custom timeout for admission analysis
  export SCC_ACTUAL_TIMEOUT="${SCC_ADMISSION_ANALYSIS_TIMEOUT}"

  log "Running SCC admission analysis for issue #${issue_number} (timeout: ${SCC_ADMISSION_ANALYSIS_TIMEOUT}s)"

  response=$(cd "${WORKDIR}" && timeout "${SCC_ADMISSION_ANALYSIS_TIMEOUT}s" \
    "${SCC_BIN}" chat --clear -m "${SCC_PROFILE}" --throttle auto -yq "${prompt}" 2>&1)
  rc=$?

  # Strip ANSI color codes that SCC may emit
  response=$(echo "${response}" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\[0m//g')

  # Log response for debugging (first 1000 chars)
  log "SCC admission analysis response (first 1000 chars): ${response:0:1000}"

  if [[ "${rc}" -eq 124 ]]; then
    log "ERROR: SCC admission analysis timed out for issue #${issue_number} after ${SCC_ADMISSION_ANALYSIS_TIMEOUT}s"
    echo '{"classification":"ERROR","reasoning":"SCC analysis timed out","missing_sections":[],"criteria_issues":[],"concerns":[],"confidence":0.0}'
    return 1
  elif [[ "${rc}" -ne 0 ]]; then
    log "ERROR: SCC admission analysis failed for issue #${issue_number} (exit code ${rc})"
    echo '{"classification":"ERROR","reasoning":"SCC analysis failed","missing_sections":[],"criteria_issues":[],"concerns":[],"confidence":0.0}'
    return 1
  fi

  # Extract JSON from response (in case SCC adds extra text)
  # Try to find JSON block - look for opening { and closing }
  local json_response

  # Method 1: Try to extract JSON using sed (handles multiline)
  json_response=$(echo "${response}" | sed -n '/{/,/}/p' | tr -d '\n' | sed 's/.*\({.*}\).*/\1/')

  # Method 2: Fallback - try jq to validate and extract
  if [[ -z "${json_response}" ]] || ! echo "${json_response}" | jq empty 2>/dev/null; then
    # Try to find JSON with python
    json_response=$(echo "${response}" | python3 -c "
import sys, json, re
text = sys.stdin.read()
# Find JSON object
match = re.search(r'\{[^}]*\"classification\"[^}]*\}', text, re.DOTALL)
if match:
    try:
        obj = json.loads(match.group(0))
        print(json.dumps(obj))
    except:
        pass
" 2>/dev/null)
  fi

  if [[ -z "${json_response}" ]]; then
    log "ERROR: No JSON response from SCC admission analysis for issue #${issue_number}"
    log "SCC raw output (first 500 chars): ${response:0:500}"
    echo '{"classification":"ERROR","reasoning":"No JSON in SCC response","missing_sections":[],"criteria_issues":[],"concerns":[],"confidence":0.0}'
    return 1
  fi

  # Validate JSON
  if ! echo "${json_response}" | jq empty 2>/dev/null; then
    log "ERROR: Invalid JSON from SCC admission analysis for issue #${issue_number}"
    log "Attempted JSON: ${json_response:0:200}"
    echo '{"classification":"ERROR","reasoning":"Invalid JSON in SCC response","missing_sections":[],"criteria_issues":[],"concerns":[],"confidence":0.0}'
    return 1
  fi

  echo "${json_response}"
  return 0
}

# Enrich an incomplete issue by filling missing sections
# Returns: enriched issue body
enrich_issue() {
  local issue_number="$1"
  local original_body="$2"
  local missing_sections="$3"
  local issue_title="$4"

  log "enrich_issue: enriching issue #${issue_number} (missing: ${missing_sections})"

  local prompt="You are enriching a GitHub issue for AI-SDLC.

**Original Issue #${issue_number}: ${issue_title}**

**Original Body:**
${original_body}

**Missing Sections:**
${missing_sections}

**Your task:**
Generate the COMPLETE issue body with ALL required sections filled in.

Use context from:
- The original issue text (expand and clarify)
- Repository structure and common patterns
- Reasonable assumptions based on the issue type
- Similar issues in the repository

**Required sections (ALL must be present):**
- **Description:** Clear, specific problem statement or feature request
- **Current state:** Describe what exists now (files, behavior, code)
- **Desired state:** Describe the target state after implementation
- **Acceptance Criteria:** 3-5 specific, verifiable items in checkbox format
  - Each criterion must be testable/verifiable
  - Use format: - [ ] Specific criterion
- **Complexity:** simple|medium|complex (assess based on scope)
- **Priority:** P1|P2|P3 (preserve if present in original, else use P3)
- **Type:** bug|feature|documentation|enhancement|test

**Guidelines:**
- Be specific and concrete (mention file paths, line numbers if inferable)
- Acceptance criteria must be VERIFIABLE (not \"make it better\", but \"button responds to click\")
- If original has partial sections, IMPROVE them (don't just copy)
- Maintain the original intent - don't change what the issue is asking for
- Add context from repository knowledge when helpful

**Output:**
The complete enriched issue body in markdown format.
Start DIRECTLY with the markdown (no preamble like \"Here is...\").
End with the standard sections in the format shown above."

  local enriched_body
  local rc

  export SCC_ACTUAL_TIMEOUT="${SCC_ENRICHMENT_TIMEOUT}"

  enriched_body=$(cd "${WORKDIR}" && timeout "${SCC_ENRICHMENT_TIMEOUT}s" \
    "${SCC_BIN}" chat --clear -m "${SCC_PROFILE}" --throttle auto -yq "${prompt}" 2>&1)
  rc=$?

  # Strip ANSI color codes
  enriched_body=$(echo "${enriched_body}" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\[0m//g')

  if [[ "${rc}" -ne 0 ]]; then
    log "ERROR: SCC enrichment failed for issue #${issue_number} (exit code ${rc})"
    return 1
  fi

  # Append enrichment notice
  enriched_body="${enriched_body}

---
📝 **Enriched by AI-SDLC Admission**

This issue was automatically enhanced with missing sections. Please review:
- ✅ If acceptable: Add label \`${ENRICHMENT_APPROVED_LABEL}\`
- ✏️ If needs changes: Edit the issue body, then add the approval label
- ❌ If incorrect: Remove \`${ENRICHED_LABEL}\` and edit manually

The enrichment is based on context from the repository and similar issues."

  echo "${enriched_body}"
  return 0
}

# Fragment a multi-criteria issue into parent + children
# Returns JSON: {"parent_body": "...", "children": [...]}
fragment_issue() {
  local issue_number="$1"
  local original_body="$2"
  local concerns="$3"
  local issue_title="$4"

  log "fragment_issue: fragmenting issue #${issue_number} into parent + children"

  # Parse concerns array from JSON
  local concerns_text
  concerns_text=$(echo "${concerns}" | jq -r '.[]' | tr '\n' ',' | sed 's/,$//')

  local prompt="You are fragmenting a multi-criteria GitHub issue into atomic children for AI-SDLC.

**Original Issue #${issue_number}: ${issue_title}**

**Original Body:**
${original_body}

**Identified Concerns (multiple unrelated tasks):**
${concerns_text}

**Your task:**
Create a PARENT issue and N CHILDREN (one child per concern).

**Requirements:**
- Each child must be ATOMIC (single concern only)
- Each child must have ALL required sections (Description, Current state, Desired state, Acceptance Criteria, Complexity, Priority, Type)
- Children must have execution ORDER (some may depend on others)
- Parent tracks overall goal and children progress
- Total children: maximum ${MAX_CHILDREN_PER_PARENT}

**Parent body should:**
- Summarize the overall goal (why these changes are grouped)
- List children with checkboxes: - [ ] #CHILD_1 - Brief description (order: 1)
- Use placeholder format #CHILD_N (will be replaced with actual issue numbers)
- Have acceptance criteria = \"All children completed and merged\"
- Include execution order for each child

**Children should:**
- Be independently implementable (except for order dependencies)
- Have specific, verifiable acceptance criteria
- Include Complexity assessment (simple|medium|complex)
- Include proper Type (bug|feature|documentation|etc)
- Have meaningful titles like: \"[Parent #${issue_number}] Specific child task\"

**Output ONLY this JSON, no additional text:**
{
  \"parent_body\": \"Complete parent issue markdown\",
  \"children\": [
    {
      \"order\": 1,
      \"title\": \"[Parent #${issue_number}] Child 1 descriptive title\",
      \"body\": \"Complete child markdown with ALL required sections\"
    },
    {
      \"order\": 2,
      \"title\": \"[Parent #${issue_number}] Child 2 descriptive title\",
      \"body\": \"Complete child markdown\"
    }
  ]
}

Children with lower order numbers will execute first. Use order to express dependencies."

  local response
  local rc

  export SCC_ACTUAL_TIMEOUT="${SCC_FRAGMENTATION_TIMEOUT}"

  response=$(cd "${WORKDIR}" && timeout "${SCC_FRAGMENTATION_TIMEOUT}s" \
    "${SCC_BIN}" chat --clear -m "${SCC_PROFILE}" --throttle auto -yq "${prompt}" 2>&1)
  rc=$?

  # Strip ANSI color codes
  response=$(echo "${response}" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\[0m//g')

  if [[ "${rc}" -ne 0 ]]; then
    log "ERROR: SCC fragmentation failed for issue #${issue_number} (exit code ${rc})"
    return 1
  fi

  # Extract JSON from response
  local json_response
  json_response=$(echo "${response}" | grep -o '{.*}' | head -1)

  if [[ -z "${json_response}" ]]; then
    log "ERROR: No JSON response from SCC fragmentation for issue #${issue_number}"
    return 1
  fi

  # Validate children count
  local children_count
  children_count=$(echo "${json_response}" | jq '.children | length')

  if [[ "${children_count}" -gt "${MAX_CHILDREN_PER_PARENT}" ]]; then
    log "ERROR: Too many children (${children_count} > ${MAX_CHILDREN_PER_PARENT}) for issue #${issue_number}"
    return 1
  fi

  echo "${json_response}"
  return 0
}

# Update parent issue with child progress
update_parent_progress() {
  local parent_number="$1"
  local child_number="$2"
  local status="$3"  # in-progress | completed | failed

  log "update_parent_progress: parent #${parent_number}, child #${child_number}, status ${status}"

  # Get current parent body
  local parent_body
  parent_body=$(gh issue view "${parent_number}" --repo "${REPO}" --json body -q '.body' 2>/dev/null)

  if [[ -z "${parent_body}" ]]; then
    log "ERROR: Cannot get parent body for #${parent_number}"
    return 1
  fi

  # Determine status icon
  local icon
  case "$status" in
    in-progress)
      icon="🔄"
      ;;
    completed)
      icon="✅"
      ;;
    failed)
      icon="❌"
      ;;
    *)
      icon="⏳"
      ;;
  esac

  # Update checkbox for this child (both unchecked and checked states)
  local updated_body
  updated_body=$(echo "${parent_body}" | sed -E "s/- \[[x ]\] #${child_number}([^0-9]|$)/- [x] ${icon} #${child_number}\1/")

  # Update parent body
  gh issue edit "${parent_number}" --repo "${REPO}" --body "${updated_body}" 2>&1 | tee -a "${LOGFILE}"

  # Add comment with timestamp
  comment_issue "${parent_number}" "${icon} **Child #${child_number} - ${status}**

Updated: $(date -u +'%Y-%m-%d %H:%M:%S UTC')"

  return 0
}

# Wait for child issue to complete (merged or failed)
wait_for_child_completion() {
  local child_number="$1"
  local max_wait_hours="${2:-48}"

  log "wait_for_child_completion: waiting for child #${child_number} (max ${max_wait_hours}h)"

  local max_wait_seconds=$((max_wait_hours * 3600))
  local elapsed=0
  local check_interval=180  # 3 minutes

  while [[ "${elapsed}" -lt "${max_wait_seconds}" ]]; do
    # Check child labels
    local child_labels
    child_labels=$(gh issue view "${child_number}" --repo "${REPO}" --json labels -q '[.labels[].name]' 2>/dev/null)

    if [[ -z "${child_labels}" ]]; then
      log "ERROR: Cannot get labels for child #${child_number}"
      return 1
    fi

    # Check if child is merged
    if echo "${child_labels}" | jq -e '. | index("'"${MERGED_LABEL}"'")' >/dev/null 2>&1; then
      log "Child #${child_number} merged successfully"
      return 0
    fi

    # Check if child failed
    if echo "${child_labels}" | jq -e '. | index("'"${FAILED_LABEL}"'")' >/dev/null 2>&1 || \
       echo "${child_labels}" | jq -e '. | index("'"${NEEDS_HUMAN_LABEL}"'")' >/dev/null 2>&1; then
      log "Child #${child_number} failed or needs human intervention"
      return 1
    fi

    # Sleep and increment
    sleep "${check_interval}"
    elapsed=$((elapsed + check_interval))

    log "wait_for_child_completion: child #${child_number} still processing (${elapsed}s elapsed)"
  done

  log "ERROR: Child #${child_number} did not complete within ${max_wait_hours}h"
  return 1
}

# Validate that all children meet parent's acceptance criteria
validate_parent() {
  local parent_number="$1"

  log "validate_parent: validating parent #${parent_number}"

  # Get parent body and acceptance criteria
  local parent_body
  parent_body=$(gh issue view "${parent_number}" --repo "${REPO}" --json body -q '.body' 2>/dev/null)

  if [[ -z "${parent_body}" ]]; then
    log "ERROR: Cannot get parent body for #${parent_number}"
    return 1
  fi

  # Extract children from parent body (find all #NUMBER references)
  local children_numbers
  children_numbers=$(echo "${parent_body}" | grep -oP '(?<=#)\d+' | sort -u | tr '\n' ' ')

  if [[ -z "${children_numbers}" ]]; then
    log "ERROR: No children found in parent #${parent_number}"
    return 1
  fi

  log "validate_parent: found children: ${children_numbers}"

  # Get PRs for all children
  local all_pr_changes=""
  for child in ${children_numbers}; do
    # Get PR number that closed this child
    local child_pr
    child_pr=$(gh issue view "${child}" --repo "${REPO}" --json closedByPr -q '.closedByPr.number // empty' 2>/dev/null)

    if [[ -z "${child_pr}" ]]; then
      log "WARNING: Child #${child} has no closing PR"
      continue
    fi

    # Get PR changes summary
    local pr_files
    pr_files=$(gh pr view "${child_pr}" --repo "${REPO}" --json files -q '.files[] | "\(.path): +\(.additions) -\(.deletions)"' 2>/dev/null)

    all_pr_changes+="
**Child #${child} (PR #${child_pr}):**
${pr_files}
"
  done

  if [[ -z "${all_pr_changes}" ]]; then
    log "ERROR: No PR changes found for any children of parent #${parent_number}"
    return 1
  fi

  # Use SCC to validate
  local prompt="You are validating a parent issue completion for AI-SDLC.

**Parent Issue #${parent_number}**

**Parent Body (includes acceptance criteria):**
${parent_body}

**Children PRs Merged:**
${all_pr_changes}

**Your task:**
Verify that all children PRs COLLECTIVELY satisfy the parent's acceptance criteria.

Look for:
- Are all parent acceptance criteria addressed by at least one child?
- Do the changes make sense together?
- Are there obvious gaps in coverage?

Be strict but fair - all parent criteria must be fully met by the collective children work.

**Output ONLY one of these:**
- \"VALIDATED\" (if all criteria met)
- \"GAPS_FOUND: <specific description of what's missing>\" (if criteria not fully met)"

  local response
  local rc

  export SCC_ACTUAL_TIMEOUT="${SCC_VALIDATION_TIMEOUT}"

  response=$(cd "${WORKDIR}" && timeout "${SCC_VALIDATION_TIMEOUT}s" \
    "${SCC_BIN}" chat --clear -m "${SCC_PROFILE}" --throttle auto -yq "${prompt}" 2>&1)
  rc=$?

  # Strip ANSI color codes
  response=$(echo "${response}" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\[0m//g')

  if [[ "${rc}" -ne 0 ]]; then
    log "ERROR: SCC validation failed for parent #${parent_number} (exit code ${rc})"
    return 1
  fi

  echo "${response}"
  return 0
}

# ============================================================================
# ENHANCED ADMISSION - RECONCILIATION FUNCTIONS
# ============================================================================

# Reconcile issues with enrichment approvals
reconcile_enrichment_approvals() {
  if [[ "${ENHANCED_ADMISSION_ENABLED}" != "true" ]]; then
    return 0
  fi

  log "reconcile_enrichment_approvals: checking for approved enrichments"

  # Find issues with scc-enrichment-approved
  local issues_json
  issues_json=$(gh issue list \
    --repo "${REPO}" \
    --state open \
    --label "${ENRICHMENT_APPROVED_LABEL}" \
    --limit 50 \
    --json number,labels)

  if [[ "${issues_json}" == "[]" ]]; then
    return 0
  fi

  local issue_numbers
  issue_numbers=$(echo "${issues_json}" | jq -r '.[].number' | tr '\n' ' ')
  log "reconcile_enrichment_approvals: processing: ${issue_numbers}"

  while IFS= read -r issue_json; do
    local number
    number=$(echo "${issue_json}" | jq -r '.number')

    log "reconcile_enrichment_approvals: approving enriched issue #${number}"

    # Remove enrichment labels, add accepted
    remove_label "${number}" "${ENRICHED_LABEL}"
    remove_label "${number}" "${ENRICHMENT_APPROVED_LABEL}"
    add_label "${number}" "${ACCEPTED_LABEL}"

    comment_issue "${number}" "✅ **Enrichment Approved**

Proceeding to admission queue..."

  done < <(echo "${issues_json}" | jq -c '.[]')
}

# Reconcile issues with fragmentation approvals
reconcile_fragmentation_approvals() {
  if [[ "${ENHANCED_ADMISSION_ENABLED}" != "true" ]]; then
    return 0
  fi

  log "reconcile_fragmentation_approvals: checking for approved fragmentations"

  # Find parent issues with scc-fragmentation-approved
  local issues_json
  issues_json=$(gh issue list \
    --repo "${REPO}" \
    --state open \
    --label "${FRAGMENTATION_APPROVED_LABEL}" \
    --label "${PARENT_LABEL}" \
    --limit 50 \
    --json number,labels)

  if [[ "${issues_json}" == "[]" ]]; then
    return 0
  fi

  local issue_numbers
  issue_numbers=$(echo "${issues_json}" | jq -r '.[].number' | tr '\n' ' ')
  log "reconcile_fragmentation_approvals: processing parents: ${issue_numbers}"

  while IFS= read -r issue_json; do
    local number
    number=$(echo "${issue_json}" | jq -r '.number')

    log "reconcile_fragmentation_approvals: starting execution for parent #${number}"

    # Remove fragmentation label, add executing
    remove_label "${number}" "${FRAGMENTATION_LABEL}"
    remove_label "${number}" "${FRAGMENTATION_APPROVED_LABEL}"
    add_label "${number}" "${PARENT_EXECUTING_LABEL}"

    comment_issue "${number}" "🚀 **Parent Execution Started**

Children will be executed sequentially in order.
Progress will be tracked in this issue."

  done < <(echo "${issues_json}" | jq -c '.[]')
}

# Execute parent children sequentially
reconcile_parent_executions() {
  if [[ "${ENHANCED_ADMISSION_ENABLED}" != "true" ]]; then
    return 0
  fi

  log "reconcile_parent_executions: checking for executing parents"

  # Find parents currently executing
  local issues_json
  issues_json=$(gh issue list \
    --repo "${REPO}" \
    --state open \
    --label "${PARENT_EXECUTING_LABEL}" \
    --limit 10 \
    --json number,body)

  if [[ "${issues_json}" == "[]" ]]; then
    return 0
  fi

  local issue_numbers
  issue_numbers=$(echo "${issues_json}" | jq -r '.[].number' | tr '\n' ' ')
  log "reconcile_parent_executions: processing parents: ${issue_numbers}"

  while IFS= read -r issue_json; do
    local parent_number
    parent_number=$(echo "${issue_json}" | jq -r '.number')
    local parent_body
    parent_body=$(echo "${issue_json}" | jq -r '.body')

    log "reconcile_parent_executions: executing children for parent #${parent_number}"

    # Extract children numbers from parent body (find unchecked children)
    local pending_children
    pending_children=$(echo "${parent_body}" | grep -oP '(?<=- \[ \] #)\d+' | head -1)

    if [[ -z "${pending_children}" ]]; then
      # All children checked - validate parent
      log "reconcile_parent_executions: all children complete for parent #${parent_number}, validating..."

      local validation_result
      validation_result=$(validate_parent "${parent_number}")

      if echo "${validation_result}" | grep -q "^VALIDATED"; then
        remove_label "${parent_number}" "${PARENT_EXECUTING_LABEL}"
        add_label "${parent_number}" "${PARENT_VALIDATED_LABEL}"
        add_label "${parent_number}" "${MERGED_LABEL}"

        gh issue close "${parent_number}" --repo "${REPO}" --comment "✅ **Parent Validated and Complete**

All child issues implemented and merged.
Parent acceptance criteria verified.

Closing parent issue." 2>&1 | tee -a "${LOGFILE}"

      else
        add_label "${parent_number}" "${NEEDS_HUMAN_LABEL}"
        comment_issue "${parent_number}" "⚠️ **Parent Validation Failed**

All children completed, but validation found gaps:

${validation_result}

Please review and either:
1. Create additional child issue to address gaps
2. Accept as-is (close parent manually)
3. Adjust parent criteria if too strict"
      fi

      continue
    fi

    # Process first pending child
    local child_number="${pending_children}"
    log "reconcile_parent_executions: processing child #${child_number}"

    # Check if child already has ready-to-implement (avoid duplicate)
    local child_labels
    child_labels=$(gh issue view "${child_number}" --repo "${REPO}" --json labels -q '[.labels[].name]' 2>/dev/null)

    if echo "${child_labels}" | jq -e '. | index("'"${TRIGGER_LABEL}"'")' >/dev/null 2>&1; then
      log "Child #${child_number} already has ${TRIGGER_LABEL}, waiting for completion..."

      # Check if completed
      if echo "${child_labels}" | jq -e '. | index("'"${MERGED_LABEL}"'")' >/dev/null 2>&1; then
        update_parent_progress "${parent_number}" "${child_number}" "completed"
      elif echo "${child_labels}" | jq -e '. | index("'"${FAILED_LABEL}"'")' >/dev/null 2>&1 || \
           echo "${child_labels}" | jq -e '. | index("'"${NEEDS_HUMAN_LABEL}"'")' >/dev/null 2>&1; then
        update_parent_progress "${parent_number}" "${child_number}" "failed"
        add_label "${parent_number}" "${NEEDS_HUMAN_LABEL}"
        comment_issue "${parent_number}" "⚠️ **Child Execution Failed**

Child #${child_number} failed or needs human intervention.

Parent execution paused. Options:
1. Fix child manually and re-run
2. Skip child (comment: skip #${child_number})
3. Abort parent (close this issue)"
      fi

      continue
    fi

    # Mark child as in-progress and add trigger label
    update_parent_progress "${parent_number}" "${child_number}" "in-progress"
    gh issue edit "${child_number}" --repo "${REPO}" --add-label "${TRIGGER_LABEL},priority:P3" 2>&1 | tee -a "${LOGFILE}"

    log "Child #${child_number} queued for execution (parent #${parent_number})"

  done < <(echo "${issues_json}" | jq -c '.[]')
}

log "Enhanced admission functions loaded (ENHANCED_ADMISSION_ENABLED=${ENHANCED_ADMISSION_ENABLED})"
