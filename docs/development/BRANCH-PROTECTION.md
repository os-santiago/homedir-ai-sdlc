# Branch Protection Configuration

**Date Configured:** 2026-08-28  
**Issue:** #22  
**Branch:** `main`

## Overview

The `main` branch is protected to maintain code quality and enforce the ADEV workflow. All changes must go through pull requests with passing CI checks.

## Current Configuration

### Required Status Checks
- **Check:** `CI / events-service`
- **Strict mode:** Enabled (branch must be up-to-date before merge)
- **Source:** `.github/workflows/ci.yml`

### Pull Request Reviews
- **Required approvals:** 0 (self-merge allowed after CI passes)
- **Dismiss stale reviews:** Disabled
- **Code owner review:** Not required

### Admin Enforcement
- **Enforce for administrators:** ✅ **Enabled**
- All users, including admins, must follow PR workflow

### Additional Settings
- **Allow force pushes:** ❌ Disabled
- **Allow deletions:** ❌ Disabled
- **Require linear history:** ❌ Disabled (merge commits allowed)
- **Require signed commits:** ❌ Disabled

## What This Means for Contributors

### ❌ Blocked Actions

```bash
# Direct push to main - BLOCKED
git push origin main
# Error: required status checks must pass before merging
```

### ✅ Required Workflow

```bash
# 1. Create branch
git checkout -b feat/my-feature

# 2. Make changes
git add .
git commit -m "feat: add feature"

# 3. Push branch
git push origin feat/my-feature

# 4. Create PR
gh pr create --title "feat: add feature" --body "Description"

# 5. Wait for CI to pass (automatic)
# Status: CI / events-service - Running...
# Status: CI / events-service - ✓ Passed

# 6. Merge PR
gh pr merge --merge --delete-branch
```

## CI Check Details

### CI / events-service

**Workflow:** `.github/workflows/ci.yml`  
**Triggers:** Pull requests, pushes to main  
**Duration:** ~2-3 minutes  

**Steps:**
1. Checkout code
2. Set up JDK 21
3. Build with Maven
4. Run tests (currently skipped, to be enabled)

**Success criteria:**
- Build completes without errors
- All tests pass (when enabled)

## Emergency Procedures

### Temporarily Disable Protection (Emergency Only)

If absolutely necessary (production outage, critical security fix):

```bash
# 1. Disable protection via GitHub API
gh api \
  --method DELETE \
  repos/os-santiago/homedir-ai-sdlc/branches/main/protection

# 2. Make emergency fix
git push origin main

# 3. Re-enable protection
./configure-branch-protection.sh
```

**Note:** Emergency disables should be:
- Logged in incident report
- Reviewed in post-mortem
- Re-enabled immediately after fix

### Bypass via PR with Fast-Track

For urgent fixes that can't wait for full CI:

1. Create PR as normal
2. If CI is failing due to infrastructure (not code):
   - Document reason in PR
   - Get explicit approval from maintainer
   - Manually merge via GitHub UI (admin override)

## Verification

### Check Current Protection Status

```bash
# View all protection rules
gh api repos/os-santiago/homedir-ai-sdlc/branches/main/protection \
  --jq '{required_status_checks, enforce_admins, required_pull_request_reviews}'

# Check specific setting
gh api repos/os-santiago/homedir-ai-sdlc/branches/main/protection \
  --jq '.enforce_admins.enabled'
```

### Test Protection

```bash
# 1. Create test branch
git checkout -b test/branch-protection
echo "test" > test.txt
git add test.txt
git commit -m "test: verify branch protection"
git push origin test/branch-protection

# 2. Try to push to main (should fail)
git checkout main
git push origin main
# Expected: Error message about required checks

# 3. Create PR and verify CI required
gh pr create --title "test: branch protection" --body "Testing"
# Check PR - should show "CI / events-service" as required
```

## Configuration Applied

Branch protection was configured directly via GitHub CLI:

```bash
gh api \
  --method PUT \
  repos/os-santiago/homedir-ai-sdlc/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI / events-service"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false
}
EOF
```

To verify current configuration:

```bash
gh api repos/os-santiago/homedir-ai-sdlc/branches/main/protection \
  --jq '{required_status_checks, enforce_admins, required_pull_request_reviews}'
```

## History

**2026-08-28:** Initial branch protection configured
- Issue: #22
- PR: (to be created)
- Configuration applied via `configure-branch-protection.sh`
- Follows ADEV practices and matches homedir repository standards

## References

- **GitHub Docs:** [Branch Protection Rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
- **ADEV Workflow:** Issue → Branch → PR → CI Green → Merge
- **Homedir Standards:** [os-santiago/homedir branch settings](https://github.com/os-santiago/homedir/settings/branches)
- **Issue #22:** [Configure branch protection](https://github.com/os-santiago/homedir-ai-sdlc/issues/22)

## Troubleshooting

### CI Check Not Running

If PR is created but CI doesn't run:

1. Check workflow file exists: `.github/workflows/ci.yml`
2. Verify trigger paths match changed files
3. Check GitHub Actions tab for errors
4. Re-run workflow manually from Actions tab

### Cannot Merge Despite Green CI

Possible causes:

1. **Branch not up to date:**
   ```bash
   git checkout your-branch
   git pull origin main
   git push origin your-branch
   ```

2. **Different check name:** Verify exact check name matches `CI / events-service`

3. **Admin enforcement:** Even admins need green CI

### Protection Accidentally Removed

Re-apply configuration via GitHub CLI:

```bash
gh api --method PUT \
  repos/os-santiago/homedir-ai-sdlc/branches/main/protection \
  --field required_status_checks='{"strict":true,"contexts":["CI / events-service"]}' \
  --field enforce_admins=true \
  --field required_pull_request_reviews='{"required_approving_review_count":0}' \
  --field restrictions=null \
  --field allow_force_pushes=false \
  --field allow_deletions=false
```

Or via GitHub Web UI:
1. Go to Settings → Branches
2. Add protection rule for `main`
3. Configure settings as documented above

## Future Enhancements

Potential improvements for consideration:

- [ ] Enable test suite in CI (currently skipped)
- [ ] Add code coverage requirements
- [ ] Add CODEOWNERS file for automatic review assignments
- [ ] Add required conversation resolution
- [ ] Add status check for security scanning
- [ ] Add status check for linting/formatting
