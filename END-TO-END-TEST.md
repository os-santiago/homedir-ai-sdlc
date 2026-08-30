# AI-SDLC End-to-End Test Guide

## Overview

This guide walks through a complete end-to-end test of the AI-SDLC system, from creating an issue in the `homedir` repository to having the autonomous worker implement it and create a pull request.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub: os-santiago/homedir                  │
│  ┌────────────┐      ┌─────────────┐      ┌──────────────┐     │
│  │   Issue    │ ───▶ │   Worker    │ ───▶ │  Pull Request│     │
│  │ #created   │      │  Detects    │      │   Created     │     │
│  └────────────┘      └─────────────┘      └──────────────┘     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              VPS: Podman Pod "ai-sdlc" (port 8081)              │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Worker Container (ai-sdlc-worker)                       │   │
│  │  - Polls GitHub every 3 minutes                          │   │
│  │  - Detects issues with "ready-to-implement" label       │   │
│  │  - Calls Implementation Service for code generation     │   │
│  │  - Creates branch, commits code, opens PR               │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Implementation Service (ai-sdlc-implementation:8082)    │   │
│  │  - Receives generation requests from Worker             │   │
│  │  - Iterative code generation (max 3 attempts)           │   │
│  │  - Quality scoring and feedback loop                    │   │
│  │  - Returns best code when threshold met (8.0/10)        │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Dashboard (ai-sdlc-dashboard:8080 → pod 8081)           │   │
│  │  - Real-time status monitoring                           │   │
│  │  - Issue/PR tracking                                     │   │
│  │  - Metrics and heartbeat display                        │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

### 1. Deployment Status

**Check that containers are running on VPS:**

```bash
# SSH to VPS
ssh $VPS_USER@$VPS_HOST

# Check pod status
podman pod ps | grep ai-sdlc

# Check container status
podman ps | grep ai-sdlc

# Expected output:
# ai-sdlc-worker         Up XX minutes
# ai-sdlc-dashboard      Up XX minutes
# ai-sdlc-implementation Up XX minutes
```

### 2. Required Secrets (GitHub Actions)

Verify these secrets are configured in repository settings:

- `GH_TOKEN` - GitHub token with repo/PR permissions
- `NVIDIA_API_KEY` - API key for LLM model (Qwen via Lite MAAS)
- `QUAY_USERNAME` - Quay.io username
- `QUAY_TOKEN` - Quay.io access token
- `VPS_HOST` - VPS hostname/IP
- `VPS_USER` - VPS SSH user
- `VPS_SSH_KEY` - VPS SSH private key

### 3. Container Images

Images should be available in quay.io:

```bash
# Check from VPS
podman pull quay.io/os-santiago/homedir-ai:worker-latest
podman pull quay.io/os-santiago/homedir-ai:dashboard-latest
podman pull quay.io/os-santiago/homedir-ai:implementation-latest
```

## Test Execution

### Phase 1: Create Test Issue

**1.1 Create issue in homedir repository:**

```bash
gh issue create \
  --repo os-santiago/homedir \
  --title "test: add new contributor badge to README" \
  --body "Add a contributor badge to README.md showing total number of contributors.

## Acceptance Criteria
- [ ] Add contributor badge below existing badges
- [ ] Use shields.io format
- [ ] Badge should be clickable linking to contributors page

## Implementation Notes
- Add to README.md after line 10 (below other badges)
- Format: [![Contributors](https://img.shields.io/github/contributors/os-santiago/homedir)](https://github.com/os-santiago/homedir/graphs/contributors)" \
  --label "ready-to-implement"
```

**Expected:** Issue created with number (e.g., #123)

### Phase 2: Worker Detection (Wait ~3 minutes)

**2.1 Monitor worker logs:**

```bash
# On VPS
podman logs -f ai-sdlc-worker

# Expected log output:
# [INFO] Starting reconcile cycle
# [INFO] Found 1 issue(s) with label 'ready-to-implement'
# [INFO] Processing issue #123: test: add new contributor badge
# [INFO] Calling implementation service for code generation...
```

**2.2 Check heartbeat:**

```bash
# On VPS
cat /var/lib/homedir-sdlc/heartbeat.json | jq '.'

# Expected:
{
  "repo": "os-santiago/homedir",
  "status": "running",
  "detail": "Processing issue #123",
  "updated_at": "2026-08-30T...",
  "container": true
}
```

### Phase 3: Implementation Service Generation

**3.1 Monitor implementation service:**

```bash
# On VPS
podman logs -f ai-sdlc-implementation

# Expected:
# [http] Received generation request for issue #123
# [iterator] Attempt 1/3: Generating code...
# [scagent] Executing: scc -yq "..."
# [quality] Parsing review JSON...
# [quality] Score: 8.5/10 (threshold: 8.0) ✓
# [http] Generation completed: score=8.5, iterations=1
```

**3.2 Test implementation service directly (optional):**

```bash
# On VPS
curl -X POST http://localhost:8082/api/implementation/generate \
  -H "Content-Type: application/json" \
  -d '{
    "issue_number": 123,
    "issue_body": "Add contributor badge",
    "acceptance_criteria": ["Add badge", "Use shields.io"],
    "max_iterations": 3,
    "quality_threshold": 8.0
  }'

# Expected JSON response:
{
  "code": "... generated code ...",
  "quality_score": 8.5,
  "iterations_used": 1,
  "feedback_history": [...],
  "selected_attempt": 1,
  "timestamp": "2026-08-30T..."
}
```

### Phase 4: PR Creation

**4.1 Check for PR creation:**

```bash
gh pr list --repo os-santiago/homedir --label "ai-sdlc-track"

# Expected:
# #124  feat: add contributor badge  scc-pr-open  about 1 minute ago
```

**4.2 Verify PR content:**

```bash
gh pr view 124 --repo os-santiago/homedir

# Verify:
# - Title matches issue
# - Description includes implementation notes
# - Branch name: feat/issue-123-add-contributor-badge
# - Labels: scc-pr-open, ai-sdlc-track
# - Linked to issue #123
```

**4.3 Check PR changes:**

```bash
gh pr diff 124 --repo os-santiago/homedir

# Verify:
# - README.md modified
# - Badge added in correct location
# - Format matches shields.io
# - Link points to contributors page
```

### Phase 5: CI/CD Verification

**5.1 Monitor CI checks:**

```bash
gh pr checks 124 --repo os-santiago/homedir

# Wait for checks to complete (usually 2-5 minutes)
# Expected: All checks passing
```

**5.2 Worker monitors check status:**

```bash
# On VPS - worker logs
podman logs ai-sdlc-worker | tail -50

# Expected:
# [INFO] PR #124 checks: passing
# [INFO] Updating label: scc-pr-open → scc-approved
```

### Phase 6: Dashboard Monitoring

**6.1 Access dashboard:**

```bash
# Open in browser
https://homedir-ai-sdlc.opensourcesantiago.io

# Or check health
curl https://homedir-ai-sdlc.opensourcesantiago.io/q/health/live
```

**6.2 Verify dashboard shows:**

- Current issues being processed
- PR status and CI results
- Worker heartbeat and uptime
- Quality scores from implementation service

## Validation Checklist

### ✅ Pre-Test Validation

- [ ] All 3 containers running on VPS
- [ ] Heartbeat file updating every 3 minutes
- [ ] Dashboard accessible at URL
- [ ] Implementation service responds to health check
- [ ] Worker logs show reconcile cycles

### ✅ Test Execution Validation

- [ ] Issue created with `ready-to-implement` label
- [ ] Worker detected issue within 3 minutes
- [ ] Implementation service called successfully
- [ ] Code generated meeting quality threshold
- [ ] Branch created in homedir repo
- [ ] Commit pushed with generated code
- [ ] PR opened and linked to issue
- [ ] CI checks triggered and passing
- [ ] Labels updated throughout workflow

### ✅ Quality Validation

- [ ] Generated code matches acceptance criteria
- [ ] Code quality score ≥ 8.0/10
- [ ] PR description includes reasoning
- [ ] Commit message follows conventions
- [ ] No security vulnerabilities introduced

## Troubleshooting

### Issue: Worker not detecting issues

```bash
# Check worker is running
podman ps | grep ai-sdlc-worker

# Check GitHub token
podman exec ai-sdlc-worker env | grep GH_TOKEN

# Verify label exactly matches
gh issue view 123 --repo os-santiago/homedir --json labels

# Check worker interval (default 180s)
podman exec ai-sdlc-worker env | grep HOMEDIR_SDLC_INTERVAL
```

### Issue: Implementation service not responding

```bash
# Check service is running
podman ps | grep ai-sdlc-implementation

# Test health endpoint
curl http://localhost:8082/health

# Check logs for errors
podman logs ai-sdlc-implementation | grep ERROR

# Verify sc-agent-cli installed
podman exec ai-sdlc-implementation which scc
podman exec ai-sdlc-implementation scc --version
```

### Issue: Code generation failing

```bash
# Check NVIDIA API key configured
podman exec ai-sdlc-implementation env | grep NVIDIA_API_KEY

# Verify sc-agent-cli config
podman exec ai-sdlc-implementation cat /root/.sc-agent/config.json

# Test direct scc call
podman exec -it ai-sdlc-implementation scc -yq "Write hello world in bash"
```

### Issue: PR not created

```bash
# Check git configuration
podman exec ai-sdlc-worker git config --list | grep user

# Verify repository access
podman exec ai-sdlc-worker gh auth status

# Check worktree exists
podman exec ai-sdlc-worker ls -la /srv/homedir-sdlc/worktrees/homedir/

# Review worker state
cat /var/lib/homedir-sdlc/issues/123.json
```

## Success Criteria

A successful end-to-end test demonstrates:

1. **Autonomous Detection:** Worker finds issue without manual intervention
2. **Quality Generation:** Implementation service produces code meeting threshold
3. **Complete Automation:** Entire flow from issue → PR with zero manual steps
4. **CI Integration:** PR triggers checks and worker monitors results
5. **Observability:** Dashboard shows real-time status throughout workflow

## Next Steps After Successful Test

1. **Scale testing:** Create multiple issues simultaneously
2. **Complexity testing:** Test with more complex requirements
3. **Failure scenarios:** Test remediation when CI fails
4. **Performance monitoring:** Track iteration counts and quality scores
5. **Production readiness:** Enable automerge for approved PRs

## Metrics to Track

Monitor these metrics over first 90 days:

- **Issue-to-PR time:** Target <5 minutes
- **First-attempt success rate:** Target >70% (score ≥8.0 on attempt 1)
- **Average iterations:** Target <2 iterations per issue
- **CI pass rate:** Target >85% of PRs pass all checks
- **Automerge rate:** Target >60% when enabled

---

**Last Updated:** 2026-08-30  
**Version:** 1.0  
**Status:** Ready for testing (pending deployment fixes)
