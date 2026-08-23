#!/usr/bin/env bash
# Enhanced validation, enrichment, and feedback functions for AI-SDLC
# Phases 2-4: Improve success rate from 85% to 95%+

# ============================================================================
# PHASE 2: ENHANCED VALIDATION
# ============================================================================

# Validate that template-required fields are present and valid
# Returns: 0 if valid, 1 with error message if invalid
validate_template_fields() {
  local issue_number="$1"
  local issue_body="$2"

  log "validate_template_fields: validating issue #${issue_number}"

  local validation_errors=()

  # 1. Validate "Affected Files" section exists and has valid paths
  if ! echo "$issue_body" | grep -qi "affected files"; then
    validation_errors+=("Missing 'Affected Files' section")
  else
    # Check if it contains actual file paths (not just the template text)
    local files_section=$(echo "$issue_body" | sed -n '/[Aa]ffected [Ff]iles/,/##/p' | head -20)

    if ! echo "$files_section" | grep -qE '\.(java|kt|xml|yml|yaml|properties|html|js|css|sql|sh)'; then
      validation_errors+=("Affected Files section exists but contains no valid file paths")
      validation_errors+=("  Expected: actual paths like 'src/main/java/ClassName.java'")
      validation_errors+=("  Found: generic or missing paths")
    fi
  fi

  # 2. Validate "Validation Command" is present and executable
  if ! echo "$issue_body" | grep -qi "validation"; then
    validation_errors+=("Missing 'Validation Command' section")
  else
    local validation_section=$(echo "$issue_body" | sed -n '/[Vv]alidation/,/##/p' | head -20)

    # Check for executable commands
    if ! echo "$validation_section" | grep -qE '(mvn|gradle|npm|yarn|curl|gh|pytest|jest|./|bash|sh)'; then
      validation_errors+=("Validation Command exists but is not executable")
      validation_errors+=("  Expected: 'mvn test -Dtest=ClassName' or 'curl ...'")
      validation_errors+=("  Found: generic text like 'tests pass' or 'manual testing'")
    fi
  fi

  # 3. Validate "Complexity" estimation is present
  if ! echo "$issue_body" | grep -qiE "(complexity|simple|medium|complex)"; then
    validation_errors+=("Missing 'Complexity' estimation")
    validation_errors+=("  Required: Simple, Medium, or Complex")
  fi

  # 4. Validate acceptance criteria count (max 2)
  local criteria_count=$(echo "$issue_body" | grep -c '^\s*-\s*\[\s*\]')
  if [ "$criteria_count" -gt 2 ]; then
    validation_errors+=("Too many acceptance criteria: found $criteria_count, maximum is 2")
    validation_errors+=("  For autonomous implementation, issues must be atomic (1-2 criteria)")
    validation_errors+=("  Consider: decompose into parent issue with ${criteria_count} child issues")
  elif [ "$criteria_count" -eq 0 ]; then
    validation_errors+=("No acceptance criteria found")
    validation_errors+=("  Expected: '- [ ] Criterion 1' format")
  fi

  # 5. Check for vague acceptance criteria
  if echo "$issue_body" | grep -iE '\[\s*\]\s*(it works|better|improve|fix|update)($|\s)'; then
    validation_errors+=("Vague acceptance criteria detected")
    validation_errors+=("  Avoid: 'it works', 'better', 'improve' without specifics")
    validation_errors+=("  Use: measurable, testable criteria")
  fi

  # Return results
  if [ ${#validation_errors[@]} -gt 0 ]; then
    log "Template validation failed for issue #${issue_number}: ${#validation_errors[@]} errors"
    printf '%s\n' "${validation_errors[@]}"
    return 1
  fi

  log "Template validation passed for issue #${issue_number}"
  return 0
}

# Extract affected files from issue body
extract_affected_files() {
  local issue_body="$1"

  # Extract files section and find paths
  echo "$issue_body" | \
    sed -n '/[Aa]ffected [Ff]iles/,/##/p' | \
    grep -oE '[-*/a-zA-Z0-9_/.]+\.(java|kt|xml|yml|yaml|properties|html|js|css|sql|sh|md)' | \
    sort -u
}

# Auto-detect affected files based on issue content
auto_detect_affected_files() {
  local issue_number="$1"
  local issue_title="$2"
  local issue_body="$3"

  log "auto_detect_affected_files: analyzing issue #${issue_number}"

  # Extract keywords from title and body
  local keywords=$(echo "$issue_title $issue_body" | \
    tr '[:upper:]' '[:lower:]' | \
    grep -oE '\b[a-z]{4,}\b' | \
    sort -u | \
    head -20)

  local detected_files=()

  # Search codebase for files matching keywords
  for keyword in $keywords; do
    # Search for Java/Kotlin classes
    local matches=$(find "${WORKDIR}" -type f \( -name "*${keyword}*.java" -o -name "*${keyword}*.kt" \) 2>/dev/null | \
      grep -v "/target/" | grep -v "/build/" | grep -v "/.git/" | head -5)

    if [ -n "$matches" ]; then
      while IFS= read -r file; do
        local relative_path="${file#${WORKDIR}/}"
        detected_files+=("$relative_path")
      done <<< "$matches"
    fi
  done

  # Return unique files
  printf '%s\n' "${detected_files[@]}" | sort -u | head -10
}

# Validate that validation command actually works
validate_validation_command() {
  local issue_number="$1"
  local validation_cmd="$2"

  log "validate_validation_command: testing command for issue #${issue_number}"

  # Safety check - don't run destructive commands
  if echo "$validation_cmd" | grep -qE '(rm|delete|drop|truncate|--force)'; then
    log "WARN: Validation command contains potentially destructive operations"
    return 1
  fi

  # Parse the command (handle mvn, gradle, npm, etc)
  local cmd_type=""
  if echo "$validation_cmd" | grep -q "mvn"; then
    cmd_type="maven"
  elif echo "$validation_cmd" | grep -q "gradle"; then
    cmd_type="gradle"
  elif echo "$validation_cmd" | grep -qE "(npm|yarn)"; then
    cmd_type="npm"
  elif echo "$validation_cmd" | grep -q "curl"; then
    cmd_type="curl"
  else
    log "WARN: Unknown validation command type: $validation_cmd"
    return 0  # Don't fail - let it through
  fi

  log "Detected validation command type: $cmd_type"

  # For Maven/Gradle, check if the test class exists
  if [[ "$cmd_type" == "maven" ]]; then
    local test_class=$(echo "$validation_cmd" | grep -oE 'Dtest=[A-Za-z0-9_]+' | cut -d= -f2)
    if [ -n "$test_class" ]; then
      if ! find "${WORKDIR}" -name "${test_class}.java" 2>/dev/null | grep -q .; then
        log "WARN: Test class ${test_class} not found in codebase"
        # Don't fail - test might be created by the implementation
      fi
    fi
  fi

  return 0
}

# Pre-flight validation before claiming an issue
pre_flight_validation() {
  local issue_number="$1"
  local issue_body="$2"

  log "pre_flight_validation: checking issue #${issue_number} before claiming"

  local affected_files=$(extract_affected_files "$issue_body")
  local missing_files=()
  local existing_files=()

  # Check which files exist
  while IFS= read -r file; do
    if [ -f "${WORKDIR}/${file}" ]; then
      existing_files+=("$file")
    else
      missing_files+=("$file")
    fi
  done <<< "$affected_files"

  # Calculate total lines of code in existing files
  local total_lines=0
  for file in "${existing_files[@]}"; do
    local lines=$(wc -l "${WORKDIR}/${file}" 2>/dev/null | awk '{print $1}')
    total_lines=$((total_lines + lines))
  done

  # Extract complexity estimate from issue
  local complexity="unknown"
  if echo "$issue_body" | grep -qi "complexity.*simple"; then
    complexity="simple"
  elif echo "$issue_body" | grep -qi "complexity.*medium"; then
    complexity="medium"
  elif echo "$issue_body" | grep -qi "complexity.*complex"; then
    complexity="complex"
  fi

  # Validate complexity estimate against file count and LOC
  local warnings=()

  if [[ "$complexity" == "simple" ]]; then
    if [ ${#existing_files[@]} -gt 1 ]; then
      warnings+=("Complexity marked 'Simple' but ${#existing_files[@]} files affected")
    fi
    if [ $total_lines -gt 100 ]; then
      warnings+=("Complexity marked 'Simple' but $total_lines total lines affected (suggest <50)")
    fi
  elif [[ "$complexity" == "medium" ]]; then
    if [ ${#existing_files[@]} -gt 3 ]; then
      warnings+=("Complexity marked 'Medium' but ${#existing_files[@]} files affected (suggest 2-3)")
    fi
    if [ $total_lines -gt 300 ]; then
      warnings+=("Complexity marked 'Medium' but $total_lines total lines affected (suggest <200)")
    fi
  fi

  # Return validation results as JSON
  cat <<EOF
{
  "issue_number": ${issue_number},
  "affected_files": ${#existing_files[@]},
  "missing_files": ${#missing_files[@]},
  "total_lines": ${total_lines},
  "complexity": "${complexity}",
  "warnings": $(printf '%s\n' "${warnings[@]}" | jq -R . | jq -s .),
  "validation_passed": $([ ${#warnings[@]} -eq 0 ] && echo "true" || echo "false")
}
EOF
}

# ============================================================================
# PHASE 3: AUTO-ENRICHMENT
# ============================================================================

# Auto-complete missing or vague fields in an issue
auto_enrich_issue() {
  local issue_number="$1"
  local issue_body="$2"
  local issue_title="$3"

  log "auto_enrich_issue: enriching issue #${issue_number}"

  local enrichments=()

  # 1. Auto-detect affected files if missing or vague
  local existing_files=$(extract_affected_files "$issue_body")
  if [ -z "$existing_files" ] || echo "$existing_files" | grep -q "path/to"; then
    log "Auto-detecting affected files for issue #${issue_number}"
    local detected=$(auto_detect_affected_files "$issue_number" "$issue_title" "$issue_body")

    if [ -n "$detected" ]; then
      enrichments+=("**Auto-detected Affected Files:**")
      while IFS= read -r file; do
        enrichments+=("- \`$file\`")
      done <<< "$detected"
      enrichments+=("")
    fi
  fi

  # 2. Suggest validation commands if missing or vague
  if ! echo "$issue_body" | grep -qE '(mvn|gradle|npm|curl|pytest)'; then
    log "Suggesting validation commands for issue #${issue_number}"

    # Detect test files from affected files
    local test_files=$(echo "$existing_files" | grep -i "test" | head -1)
    if [ -n "$test_files" ]; then
      local test_class=$(basename "$test_files" .java | sed 's/Test$//')
      enrichments+=("**Suggested Validation Command:**")
      enrichments+=("\`\`\`bash")
      enrichments+=("mvn test -Dtest=${test_class}Test")
      enrichments+=("\`\`\`")
      enrichments+=("")
    fi
  fi

  # 3. Re-estimate complexity based on analysis
  local detected_files=$(auto_detect_affected_files "$issue_number" "$issue_title" "$issue_body")
  local file_count=$(echo "$detected_files" | wc -l)

  local suggested_complexity="Medium"
  if [ $file_count -le 1 ]; then
    suggested_complexity="Simple"
  elif [ $file_count -ge 4 ]; then
    suggested_complexity="Complex"
  fi

  # Check if complexity in issue matches suggestion
  if echo "$issue_body" | grep -qi "complexity"; then
    local stated_complexity=$(echo "$issue_body" | grep -i "complexity" | grep -ioE "(simple|medium|complex)" | head -1)
    if [ -n "$stated_complexity" ] && [ "${stated_complexity,,}" != "${suggested_complexity,,}" ]; then
      enrichments+=("**Complexity Re-estimation:**")
      enrichments+=("- Current: ${stated_complexity}")
      enrichments+=("- Suggested: ${suggested_complexity} (based on $file_count affected files)")
      enrichments+=("")
    fi
  fi

  # Return enrichments
  if [ ${#enrichments[@]} -gt 0 ]; then
    printf '%s\n' "${enrichments[@]}"
    return 0
  fi

  return 1
}

# ============================================================================
# PHASE 4: FEEDBACK LOOP
# ============================================================================

# Generate specific failure explanation
generate_failure_explanation() {
  local issue_number="$1"
  local failure_reason="$2"
  local issue_body="$3"

  log "generate_failure_explanation: creating feedback for issue #${issue_number}"

  local explanation=""

  case "$failure_reason" in
    "TEMPLATE_VALIDATION_FAILED")
      explanation=$(cat <<'EOF'
## ❌ Implementation Failed - Issue Structure Problems

Your issue was rejected during **template validation**. The AI-SDLC requires specific structure for autonomous implementation.

### What Went Wrong

EOF
)
      # Add specific validation errors
      local errors=$(validate_template_fields "$issue_number" "$issue_body" 2>&1)
      explanation+="$errors"$'\n\n'

      explanation+=$(cat <<'EOF'

### How to Fix

1. **Update your issue** with the required fields
2. **Re-add** the `ready-to-implement` label
3. The AI-SDLC will re-evaluate automatically

### Need Help?

See the [Issue Template Guide](.github/ISSUE_TEMPLATE/README.md) for:
- ✅ Good issue examples
- 📋 Required field descriptions
- 🎯 Best practices for high success rate

EOF
)
      ;;

    "COMPLEXITY_MISMATCH")
      explanation=$(cat <<'EOF'
## ⚠️ Implementation Paused - Complexity Mismatch

The stated complexity doesn't match the actual scope of work.

### Analysis

EOF
)
      local validation=$(pre_flight_validation "$issue_number" "$issue_body")
      local warnings=$(echo "$validation" | jq -r '.warnings[]' 2>/dev/null)

      if [ -n "$warnings" ]; then
        while IFS= read -r warning; do
          explanation+="- $warning"$'\n'
        done <<< "$warnings"
      fi

      explanation+=$(cat <<'EOF'

### Recommendation

Consider one of:
1. **Re-estimate complexity** to match actual scope
2. **Decompose** into smaller child issues (use parent-child pattern)
3. **Reduce scope** to match stated complexity

EOF
)
      ;;

    "VALIDATION_COMMAND_FAILED")
      explanation=$(cat <<'EOF'
## ❌ Implementation Failed - Validation Command Issue

The validation command specified in the issue couldn't be executed or validated.

### Common Problems

- Command is not executable (e.g., "tests pass" instead of "mvn test")
- Test class doesn't exist yet
- Command has syntax errors
- Command requires running services

### Fix Options

**Option 1: Specify executable command**
```bash
mvn test -Dtest=YourTestClass
# or
curl http://localhost:8080/api/endpoint | jq '.field'
```

**Option 2: If test doesn't exist yet**
Add note in issue: "Test will be created as part of implementation"

EOF
)
      ;;

    *)
      explanation=$(cat <<'EOF'
## ❌ Implementation Failed

The autonomous implementation encountered an error.

### Next Steps

1. Review the error details above
2. Update the issue to address the problem
3. Re-add `ready-to-implement` label

Or remove `ready-to-implement` for manual implementation.

EOF
)
      ;;
  esac

  echo "$explanation"
}

# Post educational comment with success patterns
post_success_pattern_comment() {
  local issue_number="$1"
  local success_metrics="$2"

  local comment=$(cat <<'EOF'
## ✅ Implementation Successful!

This issue was successfully implemented by the AI-SDLC autonomous workflow.

### Success Factors

The following elements contributed to the successful autonomous implementation:

EOF
)

  # Add specific success factors
  comment+="- ✅ **Well-structured issue**: Clear acceptance criteria (≤2)"$'\n'
  comment+="- ✅ **Executable validation**: Command provided and working"$'\n'
  comment+="- ✅ **Accurate complexity**: Estimate matched actual scope"$'\n'
  comment+="- ✅ **Clear file scope**: Affected files identified"$'\n\n'

  comment+=$(cat <<'EOF'
### Metrics

EOF
)

  # Add metrics if provided
  if [ -n "$success_metrics" ]; then
    comment+="$success_metrics"$'\n\n'
  fi

  comment+=$(cat <<'EOF'

### Keep It Up!

This issue structure is a **template for success**. Copy this pattern for future autonomous implementations.

---

💡 **Tip**: Use the same structure for similar issues to maintain high success rates.

EOF
)

  echo "$comment"
}

# Track and report success/failure patterns
track_success_pattern() {
  local issue_number="$1"
  local success="$2"  # true or false
  local issue_body="$3"

  local pattern_file="${STATE_DIR}/success-patterns.jsonl"

  # Extract characteristics
  local has_affected_files=$(extract_affected_files "$issue_body" | wc -l)
  local has_validation_cmd=$(echo "$issue_body" | grep -c "mvn\|gradle\|curl")
  local criteria_count=$(echo "$issue_body" | grep -c '^\s*-\s*\[\s*\]')
  local complexity=$(echo "$issue_body" | grep -ioE "complexity.*(simple|medium|complex)" | grep -ioE "(simple|medium|complex)" | head -1)

  # Create pattern entry
  local pattern=$(cat <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "issue_number": ${issue_number},
  "success": ${success},
  "characteristics": {
    "affected_files_count": ${has_affected_files},
    "has_validation_command": $([ $has_validation_cmd -gt 0 ] && echo "true" || echo "false"),
    "acceptance_criteria_count": ${criteria_count},
    "complexity": "${complexity:-unknown}"
  }
}
EOF
)

  # Append to patterns file
  echo "$pattern" >> "$pattern_file"

  log "Tracked success pattern for issue #${issue_number}: success=${success}"
}

# Analyze success patterns and provide recommendations
analyze_success_patterns() {
  local pattern_file="${STATE_DIR}/success-patterns.jsonl"

  if [ ! -f "$pattern_file" ]; then
    log "No success patterns file found"
    return 1
  fi

  # Calculate success rates by characteristics
  local total=$(wc -l < "$pattern_file")
  local successful=$(grep '"success": true' "$pattern_file" | wc -l)
  local success_rate=$((successful * 100 / total))

  log "Overall success rate: ${success_rate}% (${successful}/${total})"

  # Success rate by complexity
  for complexity in simple medium complex; do
    local complexity_total=$(grep "\"complexity\": \"${complexity}\"" "$pattern_file" | wc -l)
    local complexity_success=$(grep "\"complexity\": \"${complexity}\"" "$pattern_file" | grep '"success": true' | wc -l)

    if [ $complexity_total -gt 0 ]; then
      local rate=$((complexity_success * 100 / complexity_total))
      log "Success rate for ${complexity}: ${rate}% (${complexity_success}/${complexity_total})"
    fi
  done

  # Success rate by criteria count
  for count in 1 2 3; do
    local count_total=$(grep "\"acceptance_criteria_count\": ${count}" "$pattern_file" | wc -l)
    local count_success=$(grep "\"acceptance_criteria_count\": ${count}" "$pattern_file" | grep '"success": true' | wc -l)

    if [ $count_total -gt 0 ]; then
      local rate=$((count_success * 100 / count_total))
      log "Success rate with ${count} criteria: ${rate}% (${count_success}/${count_total})"
    fi
  done
}

# Export functions
export -f validate_template_fields
export -f extract_affected_files
export -f auto_detect_affected_files
export -f validate_validation_command
export -f pre_flight_validation
export -f auto_enrich_issue
export -f generate_failure_explanation
export -f post_success_pattern_comment
export -f track_success_pattern
export -f analyze_success_patterns
