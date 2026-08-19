# Enhanced Admission Flow Design

**Version**: 1.0  
**Date**: 2026-08-19  
**Status**: Design Phase  

## Executive Summary

This design enhances the AI-SDLC admission process to achieve **~99.9% autonomy** by automatically handling:
1. **Incomplete issues** → SCC enrichment → user confirmation → implementation
2. **Multi-criteria issues** → SCC fragmentation → parent/children → sequential execution
3. **Complete issues** → direct implementation (current behavior)

## Current State (99% Autonomy)

**Current admission logic** (`platform/scripts/homedir-sdlc-worker.sh` lines 800-950):
```bash
admit_issue() {
  # 1. Check if issue has ready-to-implement label
  # 2. Run policy-based auto-approval
  # 3. If approved → add scc-accepted label
  # 4. If rejected → add needs-human label
}
```

**Limitation**: Issues must be perfectly formatted or they get `needs-human` label and stop.

**Gap**: ~1% of issues are rejected due to:
- Missing sections (Description, Current state, etc.)
- Vague acceptance criteria
- Multi-criteria (violates ADEV atomicity)

## Proposed Enhanced Flow

### 3-Path Admission Architecture

```
┌─────────────────────────────┐
│  New Issue with             │
│  ready-to-implement label   │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│  SCC Admission Analysis     │
│  (analyze_issue_quality)    │
└──────────┬──────────────────┘
           │
           ├─────────────┬─────────────┬──────────────┐
           ▼             ▼             ▼              ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐   ┌──────────┐
    │ COMPLETE │  │INCOMPLETE│  │  MULTI   │   │  ERROR   │
    │          │  │          │  │ CRITERIA │   │          │
    └────┬─────┘  └────┬─────┘  └────┬─────┘   └────┬─────┘
         │             │              │              │
         │             │              │              ▼
         │             │              │         needs-human
         │             │              │
         │             ▼              ▼
         │      ┌──────────────┐ ┌────────────────┐
         │      │  Enrichment  │ │ Fragmentation  │
         │      │   Workflow   │ │   Workflow     │
         │      └──────┬───────┘ └────────┬───────┘
         │             │                  │
         │             ▼                  ▼
         │      scc-enriched       scc-parent +
         │      (user approval)    scc-fragmentation
         │             │            (user approval)
         │             ▼                  │
         │      scc-enrichment-           │
         │      approved                  ▼
         │             │            scc-fragmentation-
         │             │            approved
         │             │                  │
         │             └────────┬─────────┘
         │                      │
         ▼                      ▼
    ┌────────────────────────────────┐
    │  Implementation Workflow       │
    │  (existing SCC execution)      │
    └────────────────────────────────┘
```

### Path 1: Complete Issue (Current Behavior)

**Trigger**: SCC analysis returns `COMPLETE`

**Criteria**:
- Has all required sections (Description, Current state, Desired state, Acceptance Criteria)
- Acceptance criteria are specific and verifiable
- Single concern (atomic per ADEV)
- Complexity specified

**Action**: Proceed directly to implementation (existing flow)

```bash
# No changes needed - existing logic
add_label "scc-accepted"
claim_issue
run_scc_implementation
```

### Path 2: Incomplete Issue → Enrichment

**Trigger**: SCC analysis returns `INCOMPLETE`

**Criteria**:
- Missing sections (e.g., no "Current state")
- Vague acceptance criteria
- Missing complexity
- Still atomic (single concern)

**Workflow**:

1. **SCC Enrichment** (`enrich_issue`):
   ```bash
   # Call SCC with enrichment prompt
   enriched_body=$(scc_enrich_issue "${issue_number}" "${original_body}")
   
   # Update issue body with enriched content
   gh issue edit "${issue_number}" --body "${enriched_body}"
   
   # Add label for user review
   add_label "scc-enriched"
   
   # Comment on issue
   gh issue comment "${issue_number}" --body "
   🤖 **AI-SDLC Enrichment**
   
   This issue was missing some details. I've added:
   - Missing sections (Current state, Desired state, etc.)
   - Specific acceptance criteria
   - Complexity assessment
   
   **Please review the updated issue body and:**
   - ✅ If acceptable: Add label \`scc-enrichment-approved\`
   - ❌ If needs changes: Edit the issue body and add label again
   
   The enriched content is based on context from similar issues and repository structure.
   "
   ```

2. **User Confirmation**:
   - User reviews enriched issue body
   - If OK: adds label `scc-enrichment-approved`
   - If not OK: edits body manually, then adds label

3. **Proceed to Implementation**:
   ```bash
   # Worker detects scc-enrichment-approved label
   remove_label "scc-enriched"
   add_label "scc-accepted"
   claim_issue
   run_scc_implementation
   ```

**Example**:

**Original issue** (vague):
```markdown
Fix the login

Labels: ready-to-implement, priority:P3
```

**After SCC enrichment**:
```markdown
**Description:**
Fix login button not responding on mobile devices (viewport < 768px)

**Current state:**
Login button on mobile Safari and Chrome does not respond to click events.
File: quarkus-app/src/main/resources/META-INF/resources/login.html line 42

**Desired state:**
Login button triggers authentication flow on all mobile devices

**Acceptance Criteria:**
- [ ] Login button clickable on mobile Safari (iOS 15+)
- [ ] Login button clickable on mobile Chrome (Android 12+)
- [ ] Click event handler attached correctly
- [ ] Authentication flow completes successfully on mobile

**Complexity:** simple
**Priority:** P3
**Type:** bug

---
*Enriched by AI-SDLC admission. Please confirm accuracy.*
```

### Path 3: Multi-Criteria → Parent/Children Fragmentation

**Trigger**: SCC analysis returns `MULTI_CRITERIA`

**Criteria**:
- Multiple unrelated acceptance criteria
- Changes span multiple subsystems
- Violates ADEV atomicity

**Workflow**:

1. **SCC Fragmentation** (`fragment_issue`):
   ```bash
   # Call SCC with fragmentation prompt
   fragmentation_plan=$(scc_fragment_issue "${issue_number}" "${original_body}")
   
   # Parse JSON response with parent and children
   parent_body=$(echo "$fragmentation_plan" | jq -r '.parent_body')
   children=$(echo "$fragmentation_plan" | jq -c '.children[]')
   
   # Update parent issue
   gh issue edit "${issue_number}" --body "${parent_body}"
   add_label "scc-parent"
   add_label "scc-fragmentation"
   
   # Create children issues (NOT labeled ready-to-implement yet)
   child_numbers=()
   while IFS= read -r child; do
     child_title=$(echo "$child" | jq -r '.title')
     child_body=$(echo "$child" | jq -r '.body')
     child_order=$(echo "$child" | jq -r '.order')
     
     child_number=$(gh issue create \
       --title "${child_title}" \
       --body "${child_body}
       
---
**Parent Issue:** #${issue_number}
**Execution Order:** ${child_order}
**Status:** Awaiting parent approval" \
       --label "scc-child" \
       --json number -q '.number')
     
     child_numbers+=("${child_number}")
   done <<< "${children}"
   
   # Comment on parent with fragmentation plan
   gh issue comment "${issue_number}" --body "
   🤖 **AI-SDLC Fragmentation**
   
   This issue contains multiple concerns and has been split into atomic tasks:
   
   $(for i in "${!child_numbers[@]}"; do
     echo "- [ ] #${child_numbers[$i]} (order: $((i+1)))"
   done)
   
   **Please review:**
   - Check that each child issue is correctly scoped
   - Verify execution order is appropriate
   - Edit any child issue if needed
   
   **To proceed:**
   - ✅ If acceptable: Add label \`scc-fragmentation-approved\` to THIS issue
   - ❌ If needs changes: Edit child issues, then add label
   
   Children will execute sequentially in the order above.
   "
   ```

2. **User Confirmation**:
   - User reviews parent and all children
   - Can edit any child issue body/title
   - If OK: adds label `scc-fragmentation-approved` to parent

3. **Sequential Execution** (`execute_parent_children`):
   ```bash
   # Worker detects scc-fragmentation-approved on parent
   remove_label "scc-fragmentation"
   add_label "scc-parent-executing"
   
   # Get children in order
   children=$(gh issue view "${parent_number}" --json body -q '.body' | \
              grep -oP '#\d+' | sort -u)
   
   # Execute each child sequentially
   for child in $children; do
     child_num="${child#\#}"
     
     # Update parent with current progress
     update_parent_progress "${parent_number}" "${child_num}" "in-progress"
     
     # Add ready-to-implement to child (enters normal flow)
     gh issue edit "${child_num}" --add-label "ready-to-implement,priority:P3"
     
     # Wait for child to complete (merged or failed)
     wait_for_child_completion "${child_num}"
     
     child_status=$(get_child_status "${child_num}")
     
     if [[ "${child_status}" == "merged" ]]; then
       update_parent_progress "${parent_number}" "${child_num}" "completed"
     else
       # Child failed - mark parent needs-human
       update_parent_progress "${parent_number}" "${child_num}" "failed"
       add_label "needs-human"
       gh issue comment "${parent_number}" --body "
       ⚠️ Child issue #${child_num} failed during execution.
       
       Parent execution paused. Please review the child issue and either:
       - Fix manually and mark child as resolved
       - Skip this child (comment 'skip #${child_num}')
       - Abort parent execution (close this issue)
       "
       return 1
     fi
   done
   
   # All children completed - validate parent
   validate_parent "${parent_number}"
   ```

4. **Parent Validation** (`validate_parent`):
   ```bash
   # Use SCC to verify all children meet parent's original criteria
   validation_result=$(scc_validate_parent "${parent_number}")
   
   if [[ "${validation_result}" == "VALIDATED" ]]; then
     add_label "scc-parent-validated"
     gh issue comment "${parent_number}" --body "
     ✅ **Parent Validation Complete**
     
     All child issues have been implemented and merged:
     $(list_completed_children)
     
     Parent acceptance criteria verified against child PRs.
     Closing parent issue.
     "
     gh issue close "${parent_number}"
     add_label "scc-merged"
   else
     add_label "needs-human"
     gh issue comment "${parent_number}" --body "
     ⚠️ **Parent Validation Failed**
     
     All children completed, but validation found gaps:
     ${validation_result}
     
     Please review and either:
     - Create additional child issue to address gaps
     - Close parent manually if acceptable
     "
   fi
   ```

**Example**:

**Original issue** (multi-criteria - Issue #1389):
```markdown
## Resumen
Establecer wip-pr label en múltiples archivos

## Ubicaciones
1. Crear AGENTS.md
2. Editar opencode/agents/*.md
3. Editar PR template
4. Editar CONTRIBUTING.md
5. Editar workflows
...

Labels: ready-to-implement, priority:P3
```

**After fragmentation** (Parent #1389):
```markdown
**Description:**
Establish wip-pr label convention across all repository documentation and agent configurations

**Current state:**
No centralized documentation of wip-pr label requirement for AI agents

**Desired state:**
All documentation and agent configs reference wip-pr convention

**Acceptance Criteria:**
- [ ] All child issues completed and merged (#1501, #1502, #1503, #1504)
- [ ] wip-pr convention documented in all required locations
- [ ] Agent configurations updated with wip-pr rules

**Complexity:** complex (parent of 4 children)
**Priority:** P3
**Type:** documentation

---

## Child Issues (Execute in order)

- [ ] #1501 - Create AGENTS.md with wip-pr rules (order: 1) - ✅ Merged
- [ ] #1502 - Update PR template and CONTRIBUTING.md (order: 2) - ✅ Merged
- [ ] #1503 - Update agent configs (opencode, skills) (order: 3) - 🔄 In Progress
- [ ] #1504 - Update SDLC flow documentation (order: 4) - ⏳ Pending

**Status:** Parent executing - 2/4 children completed

---
*This is a parent issue. Children will execute sequentially.*

Labels: scc-parent, scc-parent-executing, priority:P3
```

**Child #1501**:
```markdown
**Description:**
Create root-level AGENTS.md documenting wip-pr label convention for AI agents

**Current state:**
No AGENTS.md file exists in repository root

**Desired state:**
AGENTS.md file exists with wip-pr label requirement

**Acceptance Criteria:**
- [ ] File AGENTS.md created in repository root
- [ ] Documents wip-pr label requirement for all PRs
- [ ] References existing label definition
- [ ] Explains when to add and remove the label

**Complexity:** simple
**Priority:** P3
**Type:** documentation

---
**Parent Issue:** #1389
**Execution Order:** 1
**Status:** Ready for implementation

Labels: scc-child, ready-to-implement, priority:P3
```

## New Labels Required

| Label | Color | Description | When Added |
|-------|-------|-------------|------------|
| `scc-enriched` | `#FFA500` | Issue enriched by SCC, awaiting user confirmation | After enrichment |
| `scc-enrichment-approved` | `#00FF00` | User approved enriched content | Manual by user |
| `scc-parent` | `#9C27B0` | Parent issue with children | After fragmentation |
| `scc-child` | `#CE93D8` | Child issue (part of parent) | On child creation |
| `scc-fragmentation` | `#FFA500` | Fragmentation proposed, awaiting approval | After fragmentation |
| `scc-fragmentation-approved` | `#00FF00` | User approved fragmentation plan | Manual by user |
| `scc-parent-executing` | `#2196F3` | Parent executing children sequentially | During execution |
| `scc-parent-validated` | `#4CAF50` | All children completed and validated | After validation |

## Enhanced State Transitions

### Enrichment Path
```
ready-to-implement
    ↓
scc-admission-review (SCC analysis)
    ↓
scc-enriched (enrichment applied)
    ↓ (user adds scc-enrichment-approved)
scc-accepted
    ↓
scc-queued → scc-running → scc-pr-created → scc-merged
```

### Fragmentation Path
```
ready-to-implement
    ↓
scc-admission-review (SCC analysis)
    ↓
scc-parent + scc-fragmentation (children created)
    ↓ (user adds scc-fragmentation-approved)
scc-parent-executing
    ↓ (for each child in order)
    Child: scc-queued → scc-running → scc-pr-created → scc-merged
    ↓ (all children merged)
scc-parent-validated
    ↓
scc-merged (parent closed)
```

## Worker Implementation Changes

### New Functions

#### 1. SCC Admission Analysis
```bash
# Analyzes issue quality and determines path
# Returns: COMPLETE | INCOMPLETE | MULTI_CRITERIA | ERROR
analyze_issue_quality() {
  local issue_number="$1"
  local issue_body="$2"
  
  local prompt="You are analyzing a GitHub issue for the AI-SDLC admission process.

**Issue Body:**
${issue_body}

**Required Format:**
- Description: Clear problem statement
- Current state: What exists now
- Desired state: What should exist
- Acceptance Criteria: Specific, verifiable checklist
- Complexity: simple|medium|complex
- Priority: P1|P2|P3
- Type: bug|feature|documentation|etc

**ADEV Atomicity Principle:**
An issue is atomic if it addresses ONE concern. Multiple unrelated acceptance criteria = NOT atomic.

**Analyze and classify this issue:**

1. COMPLETE: Has all required sections, criteria are specific, is atomic
2. INCOMPLETE: Missing sections or vague criteria, but IS atomic (single concern)
3. MULTI_CRITERIA: Multiple unrelated concerns (violates ADEV) - needs fragmentation
4. ERROR: Cannot be processed (completely unclear, requires human judgment)

**Output JSON:**
{
  \"classification\": \"COMPLETE|INCOMPLETE|MULTI_CRITERIA|ERROR\",
  \"reasoning\": \"Why this classification\",
  \"missing_sections\": [\"list of missing required sections\"],
  \"criteria_issues\": [\"list of problems with acceptance criteria\"],
  \"concerns\": [\"list of distinct concerns if MULTI_CRITERIA\"]
}

Respond ONLY with the JSON, no additional text."
  
  local response
  response=$(scc chat -yq "${prompt}")
  
  echo "${response}"
}
```

#### 2. Issue Enrichment
```bash
# Uses SCC to fill missing sections
enrich_issue() {
  local issue_number="$1"
  local original_body="$2"
  local missing_sections="$3"
  
  local prompt="You are enriching a GitHub issue for AI-SDLC.

**Original Issue:**
${original_body}

**Missing Sections:**
${missing_sections}

**Your task:**
Generate the complete issue body with ALL required sections filled in.

Use context from:
- Repository structure (infer from similar issues)
- Common patterns for this issue type
- Reasonable assumptions based on the description

**Required sections:**
- **Description:** (if missing, expand from title/summary)
- **Current state:** (describe what exists now)
- **Desired state:** (describe target state)
- **Acceptance Criteria:** (3-5 specific, verifiable items)
- **Complexity:** simple|medium|complex
- **Priority:** P1|P2|P3 (preserve if present, else P3)
- **Type:** bug|feature|documentation|enhancement|test

**Output:**
The complete enriched issue body in markdown format. Start directly with the markdown, no preamble."
  
  local enriched_body
  enriched_body=$(scc chat -yq "${prompt}")
  
  # Append enrichment notice
  enriched_body="${enriched_body}

---
*📝 Enriched by AI-SDLC admission. Please review and confirm accuracy.*"
  
  echo "${enriched_body}"
}
```

#### 3. Issue Fragmentation
```bash
# Fragments multi-criteria issue into parent + children
fragment_issue() {
  local issue_number="$1"
  local original_body="$2"
  local concerns="$3"
  
  local prompt="You are fragmenting a multi-criteria GitHub issue into atomic children.

**Original Issue #${issue_number}:**
${original_body}

**Identified Concerns:**
${concerns}

**Your task:**
Create a parent issue and N children (one per concern).

**Requirements:**
- Each child must be ATOMIC (single concern)
- Each child must have complete sections (Description, Current state, etc.)
- Children must have execution order (some may depend on others)
- Parent tracks overall goal and children progress

**Output JSON:**
{
  \"parent_body\": \"Complete parent issue markdown\",
  \"children\": [
    {
      \"order\": 1,
      \"title\": \"[Parent #${issue_number}] Child 1 title\",
      \"body\": \"Complete child markdown with all sections\"
    },
    {
      \"order\": 2,
      \"title\": \"[Parent #${issue_number}] Child 2 title\",
      \"body\": \"Complete child markdown\"
    }
  ]
}

Parent body should:
- Summarize overall goal
- List children with checkboxes
- Reference children by placeholder (#CHILD1, #CHILD2, etc - will be replaced)
- Have acceptance criteria = all children completed

Children should:
- Be independently implementable (except for order dependencies)
- Have specific, verifiable criteria
- Include Complexity assessment

Respond ONLY with JSON."
  
  local response
  response=$(scc chat -yq "${prompt}")
  
  echo "${response}"
}
```

#### 4. Parent Validation
```bash
# Validates all children meet parent criteria
validate_parent() {
  local parent_number="$1"
  
  # Get parent body and acceptance criteria
  local parent_body
  parent_body=$(gh issue view "${parent_number}" --json body -q '.body')
  
  # Get all children PRs
  local children_prs
  children_prs=$(gh issue view "${parent_number}" --json body -q '.body' | \
                 grep -oP '#\d+' | while read child; do
    gh issue view "${child#\#}" --json closedByPr -q '.closedByPr.number'
  done)
  
  # Get changes from all PRs
  local all_changes=""
  for pr in $children_prs; do
    pr_changes=$(gh pr view "${pr}" --json files -q '.files[] | "\(.path): \(.additions) additions"')
    all_changes+="
PR #${pr}:
${pr_changes}
"
  done
  
  local prompt="You are validating a parent issue completion.

**Parent Issue #${parent_number}:**
${parent_body}

**Children PRs merged:**
${all_changes}

**Your task:**
Verify that all children PRs collectively satisfy the parent's acceptance criteria.

**Output:**
If validated: \"VALIDATED\"
If gaps found: \"GAPS_FOUND: <description of what's missing>\"

Be strict - all parent criteria must be fully met."
  
  local response
  response=$(scc chat -yq "${prompt}")
  
  echo "${response}"
}
```

#### 5. Update Parent Progress
```bash
# Updates parent issue with child progress
update_parent_progress() {
  local parent_number="$1"
  local child_number="$2"
  local status="$3"  # in-progress | completed | failed
  
  # Get current parent body
  local parent_body
  parent_body=$(gh issue view "${parent_number}" --json body -q '.body')
  
  # Update child status in parent body
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
  esac
  
  # Replace checkbox for this child
  local updated_body
  updated_body=$(echo "${parent_body}" | sed "s|- \[ \] #${child_number}|- [x] #${child_number} ${icon}|")
  
  gh issue edit "${parent_number}" --body "${updated_body}"
  
  # Comment with status
  gh issue comment "${parent_number}" --body "
${icon} **Child #${child_number} - ${status}**

$(date -u +'%Y-%m-%d %H:%M:%S UTC')
"
}
```

### Modified Worker Loop

**Current loop** (`reconcile` function):
```bash
reconcile() {
  admit_new_issues
  claim_accepted_issues
  run_scc_on_queued_issues
  create_prs_from_branches
  reconcile_merged_prs
}
```

**Enhanced loop**:
```bash
reconcile() {
  # Admission with SCC analysis
  admit_new_issues_with_analysis
  
  # Handle enrichment confirmations
  process_enrichment_approvals
  
  # Handle fragmentation confirmations
  process_fragmentation_approvals
  
  # Execute parent children sequentially
  execute_parent_children
  
  # Existing flow for accepted issues
  claim_accepted_issues
  run_scc_on_queued_issues
  create_prs_from_branches
  reconcile_merged_prs
  
  # Validate completed parents
  validate_completed_parents
}
```

## Configuration Changes

### Environment Variables

```bash
# Enable enhanced admission (feature flag)
HOMEDIR_SDLC_ENHANCED_ADMISSION=${HOMEDIR_SDLC_ENHANCED_ADMISSION:-true}

# Timeouts for SCC admission operations
SCC_ADMISSION_ANALYSIS_TIMEOUT=${SCC_ADMISSION_ANALYSIS_TIMEOUT:-120}    # 2 min
SCC_ENRICHMENT_TIMEOUT=${SCC_ENRICHMENT_TIMEOUT:-300}                    # 5 min
SCC_FRAGMENTATION_TIMEOUT=${SCC_FRAGMENTATION_TIMEOUT:-600}              # 10 min
SCC_VALIDATION_TIMEOUT=${SCC_VALIDATION_TIMEOUT:-120}                    # 2 min

# Max children per parent (safety limit)
MAX_CHILDREN_PER_PARENT=${MAX_CHILDREN_PER_PARENT:-10}
```

### Policy Updates

Add to `platform/config/autonomous-decision-policy.yaml`:

```yaml
admission:
  # ... existing policies ...
  
  enrichment:
    enabled: true
    max_sections_to_add: 5
    require_user_confirmation: true
    auto_approve_simple_enrichment: false  # Always require confirmation
  
  fragmentation:
    enabled: true
    min_concerns_for_split: 2
    max_children: 10
    require_user_confirmation: true
    sequential_execution: true
    
  parent_execution:
    wait_for_child_completion: true
    max_wait_per_child_hours: 48
    failure_handling: "pause_and_notify"  # pause_and_notify | skip_child | abort_parent
    
  validation:
    strict_mode: true  # Require all parent criteria met
    validate_via_scc: true
```

## Error Handling

### Enrichment Failures

**Scenario**: SCC cannot enrich (too vague, context missing)

**Action**:
```bash
add_label "needs-human"
gh issue comment "${issue_number}" --body "
❌ **Enrichment Failed**

Unable to automatically enrich this issue - insufficient context.

Please add:
- Clear description of the problem
- What currently exists (Current state)
- What should exist (Desired state)
- Specific steps to verify completion

Then remove 'needs-human' and re-add 'ready-to-implement'.
"
```

### Fragmentation Failures

**Scenario**: SCC cannot determine concerns or create atomic children

**Action**:
```bash
add_label "needs-human"
gh issue comment "${issue_number}" --body "
❌ **Fragmentation Failed**

This issue appears to have multiple concerns, but I cannot split it automatically.

Please either:
1. Split manually into separate issues
2. Simplify to a single concern
3. Provide clearer acceptance criteria

Then re-submit.
"
```

### Child Execution Failures

**Scenario**: Child issue fails during implementation (scc-failed)

**Action**:
```bash
# Pause parent execution
update_parent_progress "${parent_number}" "${child_number}" "failed"
add_label "needs-human" to parent

# Wait for human intervention
# User options:
# - Fix child manually → comment "retry #${child_number}"
# - Skip child → comment "skip #${child_number}"
# - Abort → close parent
```

### Parent Validation Failures

**Scenario**: All children merged but parent criteria not met

**Action**:
```bash
add_label "needs-human"
gh issue comment "${parent_number}" --body "
⚠️ **Validation Incomplete**

All children completed, but gaps found:
${validation_gaps}

Options:
1. Create additional child issue to address gaps
2. Accept as-is (close parent manually)
3. Adjust parent criteria if they were too strict
"
```

## Success Metrics

### Quantitative

- **Enrichment success rate**: Target >80% of INCOMPLETE issues successfully enriched
- **Fragmentation accuracy**: Target >90% of parent/children splits accepted by users
- **User confirmation time**: Target <24h median time for user to approve
- **Parent execution success**: Target >95% of parents complete all children
- **Overall autonomy**: Target 99.5-99.9% (up from 99%)

### Qualitative

- Reduced `needs-human` labels on incomplete issues
- Better-structured issues after enrichment
- Clearer separation of concerns via fragmentation
- Improved traceability (parent → children → PRs)

## Migration Path

### Phase 1: Labels Creation (Day 1)
```bash
gh label create "scc-enriched" --description "Issue enriched, awaiting confirmation" --color "FFA500"
gh label create "scc-enrichment-approved" --description "User approved enrichment" --color "00FF00"
gh label create "scc-parent" --description "Parent issue with children" --color "9C27B0"
gh label create "scc-child" --description "Child of parent issue" --color "CE93D8"
gh label create "scc-fragmentation" --description "Fragmentation proposed" --color "FFA500"
gh label create "scc-fragmentation-approved" --description "User approved fragmentation" --color "00FF00"
gh label create "scc-parent-executing" --description "Executing children sequentially" --color "2196F3"
gh label create "scc-parent-validated" --description "All children validated" --color "4CAF50"
```

### Phase 2: Worker Code (Day 2-5)
- Implement `analyze_issue_quality`
- Implement `enrich_issue`
- Implement `fragment_issue`
- Implement parent/children execution logic
- Implement validation logic
- Add to reconciliation loop

### Phase 3: Feature Flag Testing (Day 6-7)
- Deploy with `HOMEDIR_SDLC_ENHANCED_ADMISSION=true`
- Test with controlled issues
- Monitor metrics
- Fix bugs

### Phase 4: Full Rollout (Day 8+)
- Enable for all issues
- Monitor success rates
- Iterate based on failures

## Open Questions

1. **Should enrichment be automatic or always require confirmation?**
   - **Current design**: Always requires confirmation
   - **Alternative**: Auto-approve if confidence score > 90%

2. **Max timeout for user confirmation?**
   - **Current design**: Indefinite (waits for user)
   - **Alternative**: 72h timeout → auto-close with needs-human

3. **Should we support nested parents (parent of parents)?**
   - **Current design**: Single level only (parent → children)
   - **Alternative**: Allow 2 levels (epic → parent → children)

4. **Fragmentation rejection handling?**
   - **Current design**: User edits children, then approves
   - **Alternative**: User can request re-fragmentation with different instructions

## Appendix: Example Prompts

### SCC Admission Analysis Prompt
```
You are analyzing a GitHub issue for the AI-SDLC admission process.

**Issue Body:**
{issue_body}

**Required Format:**
[... as shown in analyze_issue_quality function ...]

Analyze and classify this issue:
1. COMPLETE
2. INCOMPLETE  
3. MULTI_CRITERIA
4. ERROR

**Output JSON:**
{...}
```

### SCC Enrichment Prompt
```
You are enriching a GitHub issue for AI-SDLC.

**Original Issue:**
{original_body}

**Missing Sections:**
{missing_sections}

Generate the complete issue body with ALL required sections filled in.
[... as shown in enrich_issue function ...]
```

### SCC Fragmentation Prompt
```
You are fragmenting a multi-criteria GitHub issue into atomic children.

**Original Issue:**
{original_body}

**Identified Concerns:**
{concerns}

Create a parent issue and N children (one per concern).
[... as shown in fragment_issue function ...]
```

### SCC Validation Prompt
```
You are validating a parent issue completion.

**Parent Issue:**
{parent_body}

**Children PRs merged:**
{all_changes}

Verify that all children PRs collectively satisfy the parent's acceptance criteria.
[... as shown in validate_parent function ...]
```

---

**Next Steps:**
1. Review and approve this design
2. Create GitHub labels (#82)
3. Implement worker functions (#77-81)
4. Update reconciliation loop (#83)
5. Test with real issues (#85)

**Estimated Implementation**: 5-7 days for full rollout
