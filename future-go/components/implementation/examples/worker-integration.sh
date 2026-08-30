#!/usr/bin/env bash
#
# Example: Worker Bash integration with Implementation Service
# This shows how to call the implementation service from homedir-sdlc-worker.sh
#

set -euo pipefail

# Configuration
IMPLEMENTATION_SERVICE_URL="${IMPLEMENTATION_SERVICE_URL:-http://localhost:8082}"
MAX_IMPLEMENTATION_ITERATIONS="${MAX_IMPLEMENTATION_ITERATIONS:-3}"
QUALITY_THRESHOLD="${QUALITY_THRESHOLD:-8.0}"

# Check if implementation service is available
check_implementation_service() {
  local url="$1"

  if curl -sf "${url}/health" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# Generate code using implementation service (multi-pass with quality)
generate_code_with_iterations() {
  local issue_number="$1"
  local issue_body="$2"
  local criteria_json="$3"  # JSON array of acceptance criteria

  local request_body
  request_body=$(cat <<EOF
{
  "issue_number": ${issue_number},
  "issue_body": $(jq -Rs . <<< "${issue_body}"),
  "acceptance_criteria": ${criteria_json},
  "max_iterations": ${MAX_IMPLEMENTATION_ITERATIONS},
  "quality_threshold": ${QUALITY_THRESHOLD}
}
EOF
)

  local response
  response=$(curl -sf -X POST "${IMPLEMENTATION_SERVICE_URL}/api/implementation/generate" \
    -H "Content-Type: application/json" \
    -d "${request_body}")

  echo "${response}"
}

# Extract generated code from response
extract_code() {
  local response="$1"
  echo "${response}" | jq -r '.code'
}

# Extract quality score from response
extract_quality_score() {
  local response="$1"
  echo "${response}" | jq -r '.quality_score'
}

# Extract iterations used from response
extract_iterations_used() {
  local response="$1"
  echo "${response}" | jq -r '.iterations_used'
}

# Example usage in worker reconcile_implementing_issues()
example_reconcile_implementing() {
  local issue_number=123
  local issue_body="Add user authentication feature..."
  local criteria_json='["Users can login", "JWT tokens issued", "Endpoints protected"]'

  echo "[worker] Processing issue #${issue_number}"

  # Try implementation service first
  if check_implementation_service "${IMPLEMENTATION_SERVICE_URL}"; then
    echo "[worker] Using implementation service for multi-pass generation"

    local response
    response=$(generate_code_with_iterations "${issue_number}" "${issue_body}" "${criteria_json}")

    local code
    code=$(extract_code "${response}")

    local quality_score
    quality_score=$(extract_quality_score "${response}")

    local iterations_used
    iterations_used=$(extract_iterations_used "${response}")

    echo "[worker] Code generated with quality ${quality_score}/10 in ${iterations_used} iterations"

    # Log to journal
    # journal "implementation_quality" "${issue_number}" "${quality_score}" "${iterations_used}"

    # Proceed to create PR with generated code
    # create_pr "${issue_number}" "${code}"

    echo "[worker] Generated code:"
    echo "${code}"

  else
    echo "[worker] Implementation service unavailable, falling back to direct SCC"

    # Fallback to current single-shot SCC generation
    # code=$(scc_generate_code "${issue_number}")
    # create_pr "${issue_number}" "${code}"
  fi
}

# Run example
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "=== Worker Integration Example ==="
  echo "Implementation Service: ${IMPLEMENTATION_SERVICE_URL}"
  echo "Max Iterations: ${MAX_IMPLEMENTATION_ITERATIONS}"
  echo "Quality Threshold: ${QUALITY_THRESHOLD}"
  echo ""

  if check_implementation_service "${IMPLEMENTATION_SERVICE_URL}"; then
    echo "✓ Implementation service is available"
    example_reconcile_implementing
  else
    echo "✗ Implementation service is NOT available at ${IMPLEMENTATION_SERVICE_URL}"
    echo "  Start the service with: cd future-go/components/implementation && make run"
    exit 1
  fi
fi
