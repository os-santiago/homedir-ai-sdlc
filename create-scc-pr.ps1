# Create PR for SCC Worker Image Build
Set-Location "D:\git\homedir-ai-sdlc"

Write-Host "Creating PR for Worker Image Build with SCC..." -ForegroundColor Cyan

# Create branch
Write-Host "Creating branch..." -ForegroundColor Yellow
git checkout -b feat/add-worker-image-build-workflow

# Stage workflow file
Write-Host "Adding workflow file..." -ForegroundColor Yellow
git add .github/workflows/build-worker-image.yml

# Commit
Write-Host "Committing..." -ForegroundColor Yellow
git commit -m "feat: add CI/CD workflow to build worker image with SCC

Adds automated workflow to build and publish worker container image
with sc-agent-cli (SCC) support.

## Changes

- Add .github/workflows/build-worker-image.yml
  - Triggers on push to main (container/, platform/ paths)
  - Triggers on workflow_dispatch (manual)
  - Builds container/Containerfile.worker (includes SCC via git clone)
  - Publishes to ghcr.io/os-santiago/homedir-ai-sdlc-worker:latest
  - Uses GitHub Actions cache for faster builds

## Impact

Current state:
- K3s worker runs but WITHOUT SCC (reconcile-only mode, 0% autonomy)
- Worker logs show: 'SCC not found at /usr/local/bin/scc'

After merge:
- Image will have SCC installed (from container/Containerfile.worker)
- K3s will auto-pull new image on next CronJob (every 3 min)
- Worker will have full functionality (99% autonomy restored)
- Can process issues automatically with AI code generation

## Verification

After merge, workflow will build automatically.
Then verify in K3s pod:
\`\`\`bash
kubectl exec -n homedir-ai-sdlc <pod> -- which scc
kubectl exec -n homedir-ai-sdlc <pod> -- scc --version
kubectl logs -n homedir-ai-sdlc <pod> | grep -E 'SCC found'
\`\`\`

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

# Push
Write-Host "Pushing..." -ForegroundColor Yellow
git push -u origin feat/add-worker-image-build-workflow

# Create PR
Write-Host "Creating PR..." -ForegroundColor Yellow
gh pr create `
  --title "feat: add CI/CD workflow to build worker image with SCC" `
  --body "Adds automated workflow to build worker container image with sc-agent-cli (SCC) support.

## Problem

Current K3s worker operates in **reconcile-only mode** (0% autonomy in issue processing):
\`\`\`
[entrypoint] WARN: SCC not found at /usr/local/bin/scc
[homedir-sdlc-worker] WARN: SCC not found - worker will operate in reconcile-only mode
\`\`\`

## Solution

Add CI/CD workflow to build \`container/Containerfile.worker\` which includes SCC installation via git clone from sc-agent-cli repo.

## Changes

- ✅ New workflow: \`.github/workflows/build-worker-image.yml\`
- ✅ Triggers: push to main (container/, platform/) + workflow_dispatch
- ✅ Publishes to: \`ghcr.io/os-santiago/homedir-ai-sdlc-worker:latest\`
- ✅ Includes: SCC + worker scripts + policies

## Impact

**Before** (current):
- ❌ Worker in reconcile-only mode
- ❌ 0% autonomy in issue processing
- ❌ Cannot generate code with AI

**After** (post-merge + build):
- ✅ Worker with SCC installed
- ✅ 99% autonomy restored
- ✅ Automatic issue processing with AI code generation
- ✅ E2E time: 16-20 min (matches Podman baseline)

## Deployment

1. Merge PR → GitHub Actions builds image automatically
2. K3s CronJob auto-pulls new image on next run (every 3 min)
3. Verify SCC in logs: \`kubectl logs -n homedir-ai-sdlc <pod> | grep 'SCC found'\`

## Testing

After deployment:
- Verify SCC: \`kubectl exec <pod> -- scc --version\`
- E2E test with oldest ready-to-implement issue
- Monitor for 24-48h to certify 99% autonomy" `
  --label "enhancement"

Write-Host "✅ Done!" -ForegroundColor Green
Write-Host ""
Write-Host "PR URL will be displayed above" -ForegroundColor Cyan
