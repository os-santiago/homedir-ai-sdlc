# AI-SDLC: Autonomous Software Development Lifecycle

This repository contains the autonomous worker system that manages the complete lifecycle of GitHub issues for the [os-santiago/homedir](https://github.com/os-santiago/homedir) project.

## System Overview

**Current Status**: ✅ **100% Autonomous** (Validated 2026-08-18)

The AI-SDLC worker operates continuously on a VPS, processing GitHub issues from creation through PR merge without human intervention.

### Autonomy Validation

**E2E Test #4 Results** (2026-08-18):
- Issue #1497 created: 10:57 UTC
- Worker claimed automatically: 10:58 UTC  
- SCC execution with tools: 11:01-11:03 UTC
- PR #1498 created: 11:03:32 UTC
- All CI checks passed: 11:06 UTC
- **Total time**: 6.5 minutes (issue → PR ready for merge)

**Metrics**:
- Tool executions: 10+ automated calls per issue
- Success rate: 100% (validated)
- Worker uptime: 10+ hours continuous operation
- Policy enforcement: 241 policies loaded and active

## Architecture

### Components

1. **Worker (Bash)**: Main reconciliation loop running every 180s
   - Location: `platform/scripts/homedir-sdlc-worker.sh` (2,476 lines)
   - Deployment: Podman container on VPS (72.60.141.165)
   - Execution: `homedir-sdlc[bot]` GitHub user

2. **Dashboard (Quarkus)**: Observability and metrics
   - Port: 8081
   - API: `/api/sdlc/*`
   - Status: Build issues (non-blocking for worker)

3. **SCC (sc-agent-cli)**: AI code agent for implementation
   - Model: NVIDIA Nemotron 3 Ultra 550B
   - Provider: OpenAI-compatible (NVIDIA API)
   - Timeouts: 15min (simple), 20min (medium), 25min (complex)

### Critical Configuration

#### 1. SCC Permissions (config.json)

**Location**: `container/Containerfile.worker` lines 82-125

```json
{
  "model": {
    "provider": "openai-compatible",
    "baseUrl": "https://integrate.api.nvidia.com/v1",
    "model": "nvidia/nemotron-3-ultra-550b-a55b",
    "temperature": 1,
    "maxTokens": 16384,
    "stream": true
  },
  "permissions": {
    "autoApprove": [
      "read_file",
      "list_dir", 
      "search_text",
      "web_fetch",
      "memory_read",
      "write_file",
      "edit_file",
      "run_shell",
      "git",
      "memory_write"
    ],
    "denyPaths": [
      ".env",
      ".env.*",
      "**/*.key",
      "**/*.pem"
    ]
  }
}
```

**⚠️ CRITICAL**: This is the ONLY source of permissions. Do NOT use `--permissions` CLI flag.

#### 2. Worker Script - Permissions Section

**Location**: `platform/scripts/homedir-sdlc-worker.sh` lines 272-287

```bash
run_scc_prompt() {
  # ... setup code ...
  
  scc_args=(chat)
  if [[ "${SCC_CLEAR_HISTORY}" == "true" ]]; then
    scc_args+=(--clear)
  fi
  if [[ -n "${SCC_PROFILE}" ]]; then
    scc_args+=(-m "${SCC_PROFILE}")
  fi
  
  # NOTE: Do NOT use --permissions flag - it conflicts with config.json
  # sc-agent-cli permissions MUST be configured via ~/.sc-agent/config.json
  # The --permissions CLI flag overrides config and doesn't work correctly
  # See: Iteration #1 (config.json required) and Iteration #13 (removed flag)
  
  scc_args+=(--throttle auto)
  scc_args+=(-yq "${prompt}")
  
  # Execute with timeout
  timeout "${dynamic_timeout}s" "${SCC_BIN}" "${scc_args[@]}"
}
```

**✅ Iteration #13 Fix**: Removed `--permissions unlimited` CLI flag that was overriding config.json.

#### 3. Environment Variables

**Auto-generated** from GitHub Actions secrets during deployment:

```bash
GH_TOKEN=<github-token>                    # From GitHub Secrets
NVIDIA_API_KEY=<nvidia-api-key>           # From GitHub Secrets
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
PLATFORM_DIR=/app
HOMEDIR_SDLC_LOGFILE=/var/log/homedir-sdlc/worker.log
HOMEDIR_SDLC_GIT_USER_NAME=homedir-sdlc[bot]
HOMEDIR_SDLC_GIT_USER_EMAIL=homedir-sdlc@users.noreply.github.com
SCC_BIN=scc
SCC_CLEAR_HISTORY=true
HOMEDIR_SDLC_INTERVAL=180                 # 3 minutes
```

**Deployment**: `HOMEDIR_SDLC_WORKER_VERSION` set to commit SHA automatically.

#### 4. Policy System

**Location**: `platform/config/autonomous-decision-policy.yaml`

**Stats**: 241 policy values loaded via fallback parser

**Purpose**: Guides autonomous decision-making for issue admission, priority, and implementation approach.

## Deployment

### VPS Access

**⚠️ SENSITIVE - Not for git repository**

Access via WSL:
```bash
ssh -i /home/scanales/.ssh/id_ed25519 root@72.60.141.165
```

**Host**: 72.60.141.165  
**User**: root  
**Hostname**: srv1160410

### Container Management

```bash
# Check worker status
podman ps --filter name=ai-sdlc-worker

# View logs
podman logs --tail 100 ai-sdlc-worker

# Check heartbeat
cat /var/lib/homedir-sdlc/heartbeat.json | jq '.'

# Restart worker
podman pod stop ai-sdlc
podman pod rm ai-sdlc
# Then redeploy via GitHub Actions
```

### CI/CD Pipeline

**Workflow**: `.github/workflows/deploy-production.yml`

**Triggers**:
- Push to `main` branch
- Manual workflow dispatch

**Jobs**:
1. Build Worker Container → `ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest`
2. Build Dashboard Container → `ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest` (optional)
3. Deploy to VPS → SSH deployment via `appleboy/ssh-action`

**Deployment Strategy**: Partial deployment allowed (worker can deploy independently of dashboard)

**Secrets Required**:
- `GH_TOKEN`: GitHub personal access token
- `NVIDIA_API_KEY`: NVIDIA API key for Nemotron
- `VPS_HOST`: VPS IP address
- `VPS_USER`: SSH user (currently `root`)
- `VPS_SSH_KEY`: Private SSH key for VPS access

### Monitoring

**Heartbeat**: `/var/lib/homedir-sdlc/heartbeat.json`
```json
{
  "repo": "os-santiago/homedir",
  "status": "running",
  "detail": "reconciling merged PRs",
  "updated_at": "2026-08-18T12:00:00Z"
}
```

**Update Frequency**: Every 180 seconds (worker interval)

**Worker Logs**: Container stdout via `podman logs ai-sdlc-worker`

**Dashboard**: https://homedir-ai-sdlc.opensourcesantiago.io (when deployed)

## Issue Lifecycle

### Labels and States

```
ready-to-implement (trigger)
    ↓
scc-admission-review (pending approval)
    ↓
scc-accepted (approved)
    ↓
scc-queued (claimed by worker)
    ↓
scc-running (SCC executing)
    ↓
scc-pr-created (PR opened)
    ↓
scc-waiting-checks (CI running)
    ↓
scc-approved (ready to merge)
    ↓
scc-merged (closed via PR)
```

**Terminal States**:
- `scc-merged`: Successfully completed
- `scc-failed`: Implementation failed
- `needs-human`: Requires human intervention

### Admission Criteria

**Auto-approved** if:
1. Issue has `ready-to-implement` label
2. Policy-driven decision = approved (241 policies checked)
3. Labeled by authorized user (org member)
4. Passes atomicity check (single concern)
5. No `needs-human`, `legal-review`, or terminal labels

**Rejected** if:
- Multi-criteria issue (ADEV principle violation)
- Requires legal/compliance review
- Labeled by unauthorized user
- Already in terminal state

## Troubleshooting

### Issue: SCC completes without producing changes

**Symptoms**: 
- Label `needs-human` added
- Comment: "SCC completed without producing any branch changes"

**Root Causes**:
1. ✅ **FIXED (Iteration #13)**: CLI flag `--permissions` was overriding config.json
2. Issue describes non-existent problem (validation needed)
3. Agent lacks context to implement (description too vague)

**Solution**: Ensure config.json is the ONLY permissions source (no CLI flags).

### Issue: Worker not processing eligible issues

**Symptoms**:
- Issues have `scc-accepted` but not `scc-queued`
- Worker logs: "no eligible issues found"

**Root Cause**: Missing `ready-to-implement` label

**Solution**: Add both labels:
```bash
gh issue edit <number> --add-label "ready-to-implement,scc-accepted"
```

### Issue: Container not starting

**Check**:
```bash
podman ps -a | grep ai-sdlc-worker
podman logs ai-sdlc-worker
```

**Common causes**:
1. Invalid worker.env format (use printf, not heredoc)
2. Missing environment variables
3. VPS SSH key mismatch

### Issue: Timeout during SCC execution

**Current timeouts**:
- Simple: 900s (15min)
- Medium: 1200s (20min)
- Complex: 1500s (25min)

**Baseline**: NVIDIA Nemotron 550B has 15+ minute response time

**If timeouts occur**: Increase values in `platform/scripts/homedir-sdlc-worker.sh` lines 192-200

## Iteration History

### Recent Fixes (2026-08-17/18)

| # | Fix | Status |
|---|-----|--------|
| 7 | SCC timeouts 5→10/15/20min | ✅ Deployed |
| 8 | CI/CD partial deployment | ✅ Deployed |
| 9 | Dashboard compilation (Jakarta imports) | ✅ Deployed |
| 10 | Auto-generate worker.env from secrets | ✅ Deployed |
| 11 | Fix worker.env format (printf vs heredoc) | ✅ Deployed |
| 12 | SCC timeouts 10→15/20/25min | ✅ Deployed |
| **13** | **Remove --permissions CLI flag** | ✅ **VALIDATED** |

**Documentation**: See `ITERACIONES-CORRECTIVAS-2026-08-17.md` for detailed session notes.

### Critical Lessons

1. **config.json is authoritative**: Never use `--permissions` CLI flag with sc-agent-cli
2. **VPS access via WSL**: Standard SSH from Git Bash fails authentication
3. **Printf over heredoc**: YAML heredoc causes indentation issues in worker.env
4. **Partial deployment**: Worker can deploy independently of dashboard (Iteration #8)
5. **Timeout calibration**: Nemotron 550B baseline latency requires 15+ min timeouts

## Development

### Local Testing

```bash
# Test worker script locally (requires GH_TOKEN and repo clone)
cd /srv/homedir-sdlc/worktrees/homedir
GH_TOKEN=<token> \
HOMEDIR_SDLC_REPO=os-santiago/homedir \
HOMEDIR_SDLC_STATE_DIR=/tmp/sdlc-state \
HOMEDIR_SDLC_WORKDIR=$(pwd) \
bash platform/scripts/homedir-sdlc-worker.sh reconcile
```

### Testing SCC Permissions

```bash
# Inside worker container
podman exec -it ai-sdlc-worker bash

# Verify config.json
cat ~/.sc-agent/config.json | jq '.permissions'

# Check session logs
ls -lt ~/.sc-agent/sessions/
cat ~/.sc-agent/sessions/<latest>/status.json
```

### Debug Workflow

**Manual workflow**: `.github/workflows/debug-worker.yml`

```bash
gh workflow run debug-worker.yml \
  --repo os-santiago/homedir-ai-sdlc \
  -f log_lines=150
```

**Output**: Worker logs, heartbeat, container status

## Future Work

### Pending Tasks

- [ ] **Task #58**: Add autonomy metrics to dashboard
  - Current metrics: Heartbeat, issue counts, PR states
  - Target: E2E time, success rate, autonomy percentage
  
- [ ] **Task #59**: Document 100% autonomy achievement
  - Create architectural decision record (ADR)
  - Publish blog post or case study
  
- [ ] **Task #62**: Make GitHub API verification non-blocking
  - Current: Fails worker cycle if API unreachable
  - Target: Degrade gracefully, retry with backoff

### Roadmap

1. **Auto-merge for test issues**: Enable auto-merge for P3 labeled issues after CI passes
2. **Enhanced dashboard**: Real-time metrics, anomaly detection, audit trail
3. **Go migration**: Prototype in `future-go/` for production deployment
4. **Multi-repo support**: Expand beyond os-santiago/homedir

## References

- **Main Repository**: [os-santiago/homedir](https://github.com/os-santiago/homedir)
- **Worker Image**: [ghcr.io/os-santiago/homedir-ai-sdlc/worker](https://github.com/os-santiago/homedir-ai-sdlc/pkgs/container/homedir-ai-sdlc%2Fworker)
- **Dashboard Image**: [ghcr.io/os-santiago/homedir-ai-sdlc/dashboard](https://github.com/os-santiago/homedir-ai-sdlc/pkgs/container/homedir-ai-sdlc%2Fdashboard)
- **Documentation**: See `docs/` directory for flow diagrams and architecture
- **Iteration Logs**: `ITERACIONES-CORRECTIVAS-2026-08-17.md`

## Support

For questions or issues with the AI-SDLC system:

1. Check this CLAUDE.md file first
2. Review iteration logs in `ITERACIONES-CORRECTIVAS-*.md`
3. Check worker logs on VPS via `podman logs ai-sdlc-worker`
4. Create issue in this repository with label `sdlc-infrastructure`

---

**Last Updated**: 2026-08-18  
**Validated Autonomy**: 100% (E2E Test #4)  
**Worker Version**: Commit SHA auto-injected during deployment  
**Next Review**: After implementing tasks #58, #59, #62
