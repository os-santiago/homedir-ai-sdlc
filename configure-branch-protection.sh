#!/bin/bash
#
# Configure branch protection for homedir-ai-sdlc main branch
# Follows ADEV practices and matches homedir repository standards
#
# Usage:
#   ./configure-branch-protection.sh
#

set -e

REPO="os-santiago/homedir-ai-sdlc"
BRANCH="main"

echo "========================================="
echo "Branch Protection Configuration"
echo "Repository: $REPO"
echo "Branch: $BRANCH"
echo "========================================="
echo ""

# Step 1: Verify current state
echo "[1/3] Checking current protection status..."
if gh api repos/$REPO/branches/$BRANCH/protection 2>&1 | grep -q "404"; then
  echo "✓ Branch is currently unprotected (expected)"
else
  echo "⚠ Branch already has protection rules"
  echo "Current configuration:"
  gh api repos/$REPO/branches/$BRANCH/protection --jq '{required_status_checks, enforce_admins, required_pull_request_reviews}'
fi
echo ""

# Step 2: Configure branch protection
echo "[2/3] Configuring branch protection..."

# Using GitHub API v3 to set branch protection
# Reference: https://docs.github.com/en/rest/branches/branch-protection

gh api \
  --method PUT \
  repos/$REPO/branches/$BRANCH/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI / events-service"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": false,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 0,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
EOF

echo "✓ Branch protection configured"
echo ""

# Step 3: Verify configuration
echo "[3/3] Verifying configuration..."
PROTECTION=$(gh api repos/$REPO/branches/$BRANCH/protection)

echo "✓ Protection rules active:"
echo ""
echo "Required Status Checks:"
echo "$PROTECTION" | jq -r '.required_status_checks.contexts[]' | sed 's/^/  - /'
echo ""
echo "Pull Request Reviews:"
echo "  - Required approvals: $(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.required_approving_review_count')"
echo "  - Dismiss stale reviews: $(echo "$PROTECTION" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews')"
echo ""
echo "Enforce for admins: $(echo "$PROTECTION" | jq -r '.enforce_admins.enabled')"
echo "Allow force pushes: $(echo "$PROTECTION" | jq -r '.allow_force_pushes.enabled')"
echo "Allow deletions: $(echo "$PROTECTION" | jq -r '.allow_deletions.enabled')"
echo ""

echo "========================================="
echo "✓ Branch protection configuration complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Test with a PR: create branch, make change, open PR"
echo "2. Verify CI must pass before merge"
echo "3. Update repository documentation"
echo ""
