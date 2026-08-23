#!/usr/bin/env bash
# CodeRabbit Integration for AI-SDLC
# Extracts and processes CodeRabbit review comments for autonomous remediation

# Extract actionable CodeRabbit comments from a PR
extract_coderabbit_comments() {
  local pr_number="$1"
  local repo="${2:-${REPO}}"

  local comments_json
  comments_json=$(gh api "repos/${repo}/pulls/${pr_number}/comments" \
    --jq '[.[] | select(.user.login == "coderabbitai[bot]") | {
      id: .id,
      path: .path,
      line: .line,
      body: .body,
      created_at: .created_at
    }]' 2>/dev/null || echo '[]')

  echo "${comments_json}"
}

# Format CodeRabbit comments for SCC prompt
format_coderabbit_feedback() {
  local comments_json="$1"

  local count
  count=$(jq 'length' <<<"${comments_json}")

  if [[ "${count}" -eq 0 ]]; then
    return 1
  fi

  cat <<EOF
CodeRabbit identified ${count} code quality improvement(s):

$(jq -r '.[] | "
File: \(.path) (line \(.line))
Suggestion:
\(.body | split("\n") | .[0:10] | join("\n"))
---"' <<<"${comments_json}")

Address these suggestions by:
1. Applying the recommended changes where they improve code quality
2. Adding tests if suggested
3. Improving documentation if requested
4. Refactoring for better maintainability

Keep changes minimal and focused on the suggestions above.
EOF
}

# Check if CodeRabbit comments are unresolved
has_unresolved_coderabbit_comments() {
  local pr_number="$1"
  local repo="${2:-${REPO}}"

  # Get review threads that are not resolved
  local unresolved_threads
  unresolved_threads=$(gh api "repos/${repo}/pulls/${pr_number}/comments" \
    --jq '[.[] | select(.user.login == "coderabbitai[bot]" and (.resolved // false) == false)] | length' \
    2>/dev/null || echo "0")

  [[ "${unresolved_threads}" -gt 0 ]]
}

# Resolve CodeRabbit comments after applying suggestions
resolve_coderabbit_comments() {
  local pr_number="$1"
  local repo="${2:-${REPO}}"
  local commit_sha="$2"

  # Mark all CodeRabbit comments as resolved
  local comment_ids
  comment_ids=$(gh api "repos/${repo}/pulls/${pr_number}/comments" \
    --jq '.[] | select(.user.login == "coderabbitai[bot]" and (.resolved // false) == false) | .id' \
    2>/dev/null || echo "")

  local resolved_count=0
  while IFS= read -r comment_id; do
    if [[ -n "${comment_id}" ]]; then
      # GitHub doesn't have a direct API to resolve comments programmatically
      # CodeRabbit will auto-resolve if the code changed addresses the comment
      # We'll add a reply comment indicating the suggestion was addressed
      gh api -X POST "repos/${repo}/pulls/${pr_number}/comments/${comment_id}/replies" \
        -f body="✅ Addressed by autonomous worker in commit ${commit_sha}" \
        2>/dev/null || true
      ((resolved_count++))
    fi
  done <<<"${comment_ids}"

  log "Added resolution notes to ${resolved_count} CodeRabbit comments"
}

# Get CodeRabbit review summary
get_coderabbit_review_summary() {
  local pr_number="$1"
  local repo="${2:-${REPO}}"

  local reviews_json
  reviews_json=$(gh pr view "${pr_number}" --repo "${repo}" --json reviews \
    --jq '.reviews[] | select(.author.login == "coderabbitai") | {
      state: .state,
      submittedAt: .submittedAt,
      body: .body
    }' 2>/dev/null || echo '{}')

  echo "${reviews_json}"
}

# Check if CodeRabbit review exists and has actionable feedback
needs_coderabbit_remediation() {
  local pr_number="$1"
  local repo="${2:-${REPO}}"

  local comments_json
  comments_json=$(extract_coderabbit_comments "${pr_number}" "${repo}")

  local count
  count=$(jq 'length' <<<"${comments_json}")

  # If there are CodeRabbit comments, we need remediation
  [[ "${count}" -gt 0 ]]
}

# Export functions for use in worker
export -f extract_coderabbit_comments
export -f format_coderabbit_feedback
export -f has_unresolved_coderabbit_comments
export -f resolve_coderabbit_comments
export -f get_coderabbit_review_summary
export -f needs_coderabbit_remediation
