#!/usr/bin/env bash
# ============================================================================
# Policy Loader - Load and parse autonomous decision policies
# ============================================================================
#
# Loads autonomous-decision-policy.yaml and makes policies available to worker
#
# Usage:
#   source platform/scripts/policy-loader.sh
#   load_policies
#   get_policy "performance.api_response_time.target_ms"  # Returns: 200
#
# ============================================================================

set -euo pipefail

# Policy file location
readonly POLICY_FILE="${PLATFORM_DIR:-platform}/config/autonomous-decision-policy.yaml"

# Global associative array for policies (bash 4+)
declare -gA POLICIES

# ============================================================================
# Load policies from YAML file
# ============================================================================
load_policies() {
  local policy_file="$POLICY_FILE"

  if [[ ! -f "$policy_file" ]]; then
    log "WARN" "Policy file not found: $policy_file"
    log "WARN" "Using autonomous guidelines only (no policies)"
    return 1
  fi

  log "INFO" "Loading policies from: $policy_file"

  # Parse YAML to flat dot-notation keys
  # Uses yq if available (mikefarah/yq v4+), falls back to built-in parser
  if command -v yq &>/dev/null && yq --version 2>/dev/null | grep -q "mikefarah"; then
    local loaded
    loaded=$(yq eval -r '[paths(scalars) as $path | {"key": ($path | join(".")), "value": getpath($path)}] | .[] | [.key, .value] | join("=")' "$policy_file" 2>/dev/null) || loaded=""
    if [[ -n "$loaded" ]]; then
      while IFS="=" read -r full_key value; do
        [[ -z "$full_key" ]] && continue
        POLICIES["$full_key"]="$value"
        log "DEBUG" "Loaded policy: $full_key = $value"
      done <<< "$loaded"
      log "INFO" "Loaded ${#POLICIES[@]} policy values via yq"
      return 0
    fi
    log "WARN" "yq parse failed, falling back to built-in parser"
  fi

  _load_policies_fallback "$policy_file"
  return $?
}

# ============================================================================
# Fallback policy loader (bash-only, no external tools)
# ============================================================================
_load_policies_fallback() {
  local policy_file="$1"
  local parent_keys=()
  local indent_stack=()
  local current_indent=0
  local line_num=0
  local loaded_count=0

  log "INFO" "Using fallback YAML parser (bash-only)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    ((line_num++))

    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue

    # Skip lines with multiline string markers (|, >, etc)
    [[ "$line" =~ :[[:space:]]*[\|\>].*$ ]] && continue

    # Measure indentation (spaces only, each 2 spaces = 1 level)
    local indent=0
    if [[ "$line" =~ ^([[:space:]]*) ]]; then
      local spaces="${BASH_REMATCH[1]}"
      indent=$((${#spaces} / 2))
    fi

    # Extract key and value
    local key value
    if [[ "$line" =~ ^[[:space:]]*([a-zA-Z0-9_-]+)[[:space:]]*:[[:space:]]*(.*)$ ]]; then
      key="${BASH_REMATCH[1]}"
      value="${BASH_REMATCH[2]}"
    elif [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.+)$ ]]; then
      # Skip list items for now (arrays not supported in simple parser)
      continue
    else
      continue
    fi

    # Clean up value (remove quotes, trim whitespace)
    value="${value#\"}"
    value="${value%\"}"
    value="${value#\'}"
    value="${value%\'}"
    value="${value## }"
    value="${value%% }"

    # Adjust parent key stack based on indentation
    while [[ ${#indent_stack[@]} -gt 0 ]] && [[ $indent -le ${indent_stack[-1]} ]]; do
      unset 'parent_keys[-1]'
      unset 'indent_stack[-1]'
    done

    # Build full key path
    local full_key="$key"
    if [[ ${#parent_keys[@]} -gt 0 ]]; then
      full_key="$(IFS=.; echo "${parent_keys[*]}").$key"
    fi

    # Store only scalar values (skip if value is empty - it's a parent key)
    if [[ -n "$value" ]] && [[ ! "$value" =~ ^[[:space:]]*$ ]]; then
      POLICIES["$full_key"]="$value"
      ((loaded_count++))
      log "DEBUG" "Loaded policy: $full_key = $value"
    fi

    # If value is empty, this is a parent key - push to stack
    if [[ -z "$value" ]] || [[ "$value" =~ ^[[:space:]]*$ ]]; then
      parent_keys+=("$key")
      indent_stack+=("$indent")
    fi

  done < "$policy_file"

  log "INFO" "Loaded $loaded_count policy values via fallback parser"

  if [[ $loaded_count -eq 0 ]]; then
    log "WARN" "No policies loaded - parser may need adjustment for this YAML format"
    return 1
  fi

  return 0
}

# ============================================================================
# Get policy value by key path
# ============================================================================
# Usage: get_policy "performance.api_response_time.target_ms"
# Returns: 200 (or empty string if not found)
get_policy() {
  local key="$1"
  echo "${POLICIES[$key]:-}"
}

# ============================================================================
# Check if policy exists
# ============================================================================
# Usage: has_policy "performance.api_response_time"
# Returns: 0 if exists, 1 if not
has_policy() {
  local key="$1"
  [[ -n "${POLICIES[$key]:-}" ]]
}

# ============================================================================
# Get all policy keys matching prefix
# ============================================================================
# Usage: get_policy_keys "performance.api_response_time"
# Returns: Array of matching keys
get_policy_keys() {
  local prefix="$1"
  local keys=()

  for key in "${!POLICIES[@]}"; do
    if [[ "$key" == "$prefix"* ]]; then
      keys+=("$key")
    fi
  done

  printf '%s\n' "${keys[@]}"
}

# ============================================================================
# Export policies as environment variables
# ============================================================================
# Converts: performance.api_response_time.target_ms = 200
# To:       POLICY_PERFORMANCE_API_RESPONSE_TIME_TARGET_MS=200
export_policies_as_env() {
  for key in "${!POLICIES[@]}"; do
    local env_var="POLICY_${key^^}"  # Uppercase
    env_var="${env_var//./_}"        # Replace dots with underscores
    export "$env_var"="${POLICIES[$key]}"
  done

  log "INFO" "Exported ${#POLICIES[@]} policies as environment variables"
}

# ============================================================================
# Get policy section as JSON
# ============================================================================
# Usage: get_policy_section_json "performance"
# Returns: JSON object with all performance.* policies
get_policy_section_json() {
  local section="$1"
  local json="{"
  local first=true

  for key in "${!POLICIES[@]}"; do
    if [[ "$key" == "$section"* ]]; then
      local short_key="${key#$section.}"  # Remove section prefix
      local value="${POLICIES[$key]}"

      if [[ "$first" == true ]]; then
        first=false
      else
        json+=","
      fi

      json+="\"$short_key\":\"$value\""
    fi
  done

  json+="}"
  echo "$json"
}

# ============================================================================
# Validate policy file syntax
# ============================================================================
validate_policy_file() {
  local policy_file="$POLICY_FILE"

  if [[ ! -f "$policy_file" ]]; then
    log "ERROR" "Policy file not found: $policy_file"
    return 1
  fi

  # Check for required sections
  local required_sections=(
    "performance"
    "rate_limiting"
    "architecture"
    "dependencies"
    "compliance"
    "error_handling"
  )

  for section in "${required_sections[@]}"; do
    if ! grep -q "^${section}:" "$policy_file"; then
      log "ERROR" "Missing required section: $section"
      return 1
    fi
  done

  log "INFO" "Policy file validation passed"
  return 0
}

# ============================================================================
# Helper: Log function (if not already defined)
# ============================================================================
if ! declare -f log >/dev/null; then
  log() {
    local level="$1"
    shift
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [$level] $*" >&2
  }
fi

# ============================================================================
# Policy-based decision for issue auto-approval
# ============================================================================
# Returns JSON decision for whether an issue can be auto-approved
# Usage: get_policy_decision <issue_number> <title> <body>
# Returns: JSON with {category, decision, rationale, policy, requires_approval}
get_policy_decision() {
  local number="$1"
  local title="$2"
  local body="$3"

  # Normalize title and body to lowercase for matching
  local title_lower="${title,,}"
  local body_lower="${body,,}"
  local combined="${title_lower} ${body_lower}"

  # ============================================================================
  # SECURITY/CRITICAL - Always require manual approval
  # ============================================================================
  if [[ "$combined" =~ (security|auth|password|credential|token|secret|vulnerability|exploit|injection|xss|csrf|cve-) ]]; then
    cat <<EOF
{
  "category": "security",
  "decision": "Requires manual security review",
  "rationale": "Issue contains security-related keywords that require human review",
  "policy": "security.require_review",
  "requires_approval": true
}
EOF
    return 0
  fi

  # Database schema changes - require approval
  if [[ "$combined" =~ (database[[:space:]]migration|alter[[:space:]]table|drop[[:space:]]table|schema[[:space:]]change|add[[:space:]]column|remove[[:space:]]column) ]]; then
    cat <<EOF
{
  "category": "database",
  "decision": "Requires manual review for schema changes",
  "rationale": "Database schema modifications require careful review to prevent data loss",
  "policy": "database.schema_changes.require_review",
  "requires_approval": true
}
EOF
    return 0
  fi

  # Legal/compliance - require approval
  if [[ "$combined" =~ (gdpr|privacy[[:space:]]policy|terms[[:space:]]of[[:space:]]service|legal|compliance|copyright|license[[:space:]]change) ]]; then
    cat <<EOF
{
  "category": "legal",
  "decision": "Requires legal review",
  "rationale": "Issue involves legal or compliance considerations",
  "policy": "legal.require_review",
  "requires_approval": true,
  "requires_legal": true
}
EOF
    return 0
  fi

  # ============================================================================
  # AUTO-APPROVE - Simple, low-risk changes
  # ============================================================================

  # Simple typo fixes
  if [[ "$title_lower" =~ ^.*\[?typo\]?.*$ ]] || [[ "$title_lower" =~ fix.*typo ]] || [[ "$title_lower" =~ correct.*spelling ]]; then
    cat <<EOF
{
  "category": "typo",
  "decision": "Auto-approve typo fix",
  "rationale": "Typo fixes are low-risk changes that improve code quality",
  "policy": "quality.typo_fixes.auto_approve",
  "requires_approval": false
}
EOF
    return 0
  fi

  # CSS/styling fixes
  if [[ "$title_lower" =~ (css|style|styling|layout|visual|overflow|display) ]] && [[ "$title_lower" =~ (fix|bug) ]]; then
    # Check if it's simple (no security keywords, not responsive redesign)
    if [[ ! "$combined" =~ (redesign|rewrite|responsive|mobile|tablet) ]]; then
      cat <<EOF
{
  "category": "styling",
  "decision": "Auto-approve CSS/styling fix",
  "rationale": "Simple CSS fixes are low-risk and easily reversible",
  "policy": "frontend.css_fixes.auto_approve",
  "requires_approval": false
}
EOF
      return 0
    fi
  fi

  # Documentation improvements
  if [[ "$title_lower" =~ (doc|documentation|readme|comment|javadoc) ]] && [[ "$title_lower" =~ (fix|update|improve|add) ]]; then
    cat <<EOF
{
  "category": "documentation",
  "decision": "Auto-approve documentation improvement",
  "rationale": "Documentation updates are low-risk and improve code maintainability",
  "policy": "quality.documentation.auto_approve",
  "requires_approval": false
}
EOF
    return 0
  fi

  # Simple UI text changes (i18n, labels, messages)
  if [[ "$title_lower" =~ (text|label|message|i18n|translation) ]] && [[ "$title_lower" =~ (fix|update|correct|change) ]]; then
    if [[ ! "$combined" =~ (legal|terms|privacy|error[[:space:]]handling) ]]; then
      cat <<EOF
{
  "category": "ui_text",
  "decision": "Auto-approve UI text change",
  "rationale": "Simple text updates are low-risk cosmetic changes",
  "policy": "frontend.ui_text.auto_approve",
  "requires_approval": false
}
EOF
      return 0
    fi
  fi

  # Performance optimization (if clear and specific)
  if [[ "$title_lower" =~ (performance|slow|optimize|speed) ]] && [[ "$title_lower" =~ (fix|improve) ]]; then
    # Auto-approve only simple optimizations (caching, indexing)
    if [[ "$combined" =~ (cache|caching|index|query[[:space:]]optimization) ]]; then
      cat <<EOF
{
  "category": "performance",
  "decision": "Auto-approve performance optimization",
  "rationale": "Specific performance fixes (caching/indexing) are generally safe improvements",
  "policy": "performance.optimization.auto_approve",
  "requires_approval": false
}
EOF
      return 0
    fi
  fi

  # ============================================================================
  # DEFAULT - Require manual review for unclear cases
  # ============================================================================
  cat <<EOF
{
  "category": "general",
  "decision": "Requires manual review",
  "rationale": "Issue does not match any auto-approval policy",
  "policy": "default.require_review",
  "requires_approval": true
}
EOF
  return 0
}

# ============================================================================
# Auto-load on source (optional)
# ============================================================================
# Uncomment to auto-load when script is sourced
# load_policies || true
