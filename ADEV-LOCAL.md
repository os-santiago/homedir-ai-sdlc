# Homedir AI-SDLC Specific Doctrine
## Local Extension to A-Dev Framework

**Repository**: github.com/os-santiago/homedir-ai-sdlc  
**Version**: 1.0  
**Last Updated**: 2026-08-24

---

## Technology Stack

### Core Technologies
- **Language**: Bash 5.x
- **AI Engine**: SCC (sc-agent-cli) - Claude Code
- **Deployment**: K3s CronJob (every 3 minutes)
- **State**: File-based in /var/lib/homedir-sdlc/
- **Dashboard**: Quarkus 3.16 (observability)

### Key Components
- Worker: `platform/scripts/homedir-sdlc-worker.sh` (2,476 lines)
- Enhanced Admission: `platform/scripts/enhanced-admission-functions.sh`
- Policy System: `platform/config/autonomous-decision-policy.yaml` (723 lines)
- Dashboard: `dashboard/quarkus-app/` (API + SPA)

---

## Deployment Model

### K3s CronJob Architecture
```yaml
CronJob: homedir-sdlc-worker
Schedule: "*/3 * * * *" (every 3 minutes)
Image: ghcr.io/os-santiago/homedir-ai-sdlc-worker:latest
Resources:
  requests: {memory: 512Mi, cpu: 100m}
  limits: {memory: 1Gi, cpu: 500m}
State Volume: /var/lib/homedir-sdlc (PVC)
```

### Deployment Strategy
- **No downtime**: CronJob runs continuously
- **State persistence**: PVC for state files
- **Auto-pull**: K3s pulls latest image every 3 min
- **Observability**: Dashboard tracks metrics

---

## Quality Gates (extends A-Dev QUALITY.md)

### Build Phase
```bash
# Container build
podman build -f container/Containerfile.worker -t worker:test .

# Shellcheck
shellcheck platform/scripts/*.sh
```

### Run Phase
```bash
# Local test (one cycle)
./platform/scripts/homedir-sdlc-worker.sh reconcile

# Integration test
./platform/scripts/test-admission.sh

# Health check
curl http://localhost:8081/api/sdlc/heartbeat
```

### Walkthrough Phase
- **E2E Flow**: Issue → Admission → SCC → PR → Merge
- **Persona**: AI-SDLC as autonomous agent
- **Validation**: Check state files, logs, PRs created
- **Metrics**: Autonomy %, heartbeat age, success rate

### Evidence Phase
- Container image published to ghcr.io
- K3s logs show successful execution
- Dashboard shows updated metrics
- Issue closed or PR created

---

## Specific Constraints

### Worker Idempotency
- **MUST** be safe to run multiple times
- Check lock file before execution
- Update heartbeat on every run
- Never process same issue twice

### State Management
- **Source of truth**: `/var/lib/homedir-sdlc/` files
- Never delete state without backup
- JSON format for structured data
- Atomic writes (write to .tmp, then mv)

### Enhanced Admission
- **MUST** run before implementation
- Classification: COMPLETE | INCOMPLETE | MULTI_CRITERIA | ERROR
- Enrichment if INCOMPLETE
- Fragmentation if MULTI_CRITERIA
- Human escalation if ERROR

### SCC Integration
- Dynamic timeouts (600-1800s)
- Retry on failure (max 3 attempts)
- Log all SCC interactions
- Never trust SCC output blindly (validate)

### Pull Request Creation
- **MUST** link to issue (`Closes #123`)
- Conventional commit format
- Include test plan in description
- Auto-label based on state

---

## Branch Workflow (extends A-Dev)

### Branch Names
```bash
# AI-SDLC generated branches
scc/issue-123-feature-name
scc/fix-456-bug-description

# Human branches
feat/add-context-engineering
fix/worker-timeout-issue
docs/update-architecture
```

### PR Requirements
- Title: Conventional commits
- Body: Links to issue
- Labels: Automated via workflows
- CI: All checks green (build, shellcheck, tests)
- Review: Self-approve for AI-SDLC issues

---

## CI/CD Pipeline

### GitHub Actions Workflows
1. **build-worker-image.yml**: Build and publish container
2. **pr-quality-check.yml**: Validate PR standards
3. **pr-state-labeler.yml**: Auto-label based on state
4. **issue-triage.yml**: Auto-triage new issues

### Quality Checks
- ✅ Shellcheck passes
- ✅ Container builds successfully
- ✅ No secrets in code
- ✅ Scripts have execute permissions
- ✅ YAML syntax valid

---

## Specific Patterns

### Worker Script Pattern
```bash
#!/usr/bin/env bash
set -euo pipefail

# Load environment
ENV_FILE="${HOMEDIR_SDLC_ENV_FILE:-/etc/homedir-sdlc.env}"
[[ -f "${ENV_FILE}" ]] && source "${ENV_FILE}"

# Acquire lock
exec 200>/var/lib/homedir-sdlc/worker.lock
flock -n 200 || { log "Another instance running"; exit 0; }

# Main logic
main() {
    log "Starting cycle"
    # ... work ...
    update_heartbeat
}

# Cleanup
trap cleanup EXIT
main "$@"
```

### SCC Invocation Pattern
```bash
run_scc_prompt() {
    local prompt="$1"
    local issue_body="${2:-}"
    
    log "Running SCC: ${prompt:0:100}..."
    
    local response
    response=$(cd "${WORKDIR}" && \
        timeout "${SCC_TIMEOUT}s" \
        scc chat --clear -m "${SCC_PROFILE}" -yq "${prompt}")
    
    local rc=$?
    [[ ${rc} -eq 0 ]] || log "SCC failed with exit code ${rc}"
    
    echo "${response}"
    return ${rc}
}
```

### State File Pattern
```bash
# Write atomically
update_state() {
    local state_file="$1"
    local content="$2"
    
    echo "${content}" > "${state_file}.tmp"
    mv "${state_file}.tmp" "${state_file}"
}

# Read with fallback
read_state() {
    local state_file="$1"
    local default="${2:-{}}"
    
    [[ -f "${state_file}" ]] && cat "${state_file}" || echo "${default}"
}
```

---

## Common Pitfalls (Anti-Patterns)

### ❌ Don't
- Run worker without lock file
- Delete state files without backup
- Skip enhanced admission
- Trust SCC output without validation
- Create PR without linking issue
- Modify production state files directly

### ✅ Do
- Always check lock before running
- Backup state before modifications
- Run admission before implementation
- Validate SCC output (syntax, completeness)
- Link all PRs to issues
- Use state update functions (atomic writes)

---

## Observability

### Metrics
- **Heartbeat**: `/var/lib/homedir-sdlc/heartbeat.json`
- **Metrics**: API `/api/sdlc/metrics`
- **Dashboard**: http://vps:8081/sdlc/dashboard/

### Key Metrics
```json
{
  "heartbeat_age_seconds": "< 300 (5 min)",
  "issues_processed_per_hour": ">= 1",
  "autonomy_percentage": ">= 70%",
  "pr_success_rate": ">= 90%",
  "ci_pass_rate": ">= 95%"
}
```

### Logging
- Location: K3s logs (`kubectl logs`)
- Format: `[TIMESTAMP] [LEVEL] [COMPONENT] message`
- Levels: INFO (normal), WARN (attention), ERROR (failure)
- Never log: GH_TOKEN, secrets

---

## Decision Log

### ADR Location
`docs/decisions/` or embedded in `ADEV-LOCAL.md`

### Recent Decisions
- **2026-07**: Enhanced admission with SCC-based triage
- **2026-08**: Migration from Podman to K3s
- **2026-08**: Container-based deployment (not systemd scripts)

---

## Continuous Improvement

### When to Update This Document
- New admission phase added
- SCC integration pattern changes
- State management evolves
- Quality gate updated
- Failure pattern discovered

### Evidence-Based Updates
Every update must reference:
- Issue number where need discovered
- PR that implemented change
- Logs/metrics showing improvement

---

## Meta-Validation

### Self-Improvement via AI-SDLC
This system should be able to improve itself:
- Issues in this repo processed by this worker
- PRs created following own standards
- Quality gates applied to own code
- Meta-testing validates the system

### Bootstrap Problem
To change AI-SDLC behavior:
1. Worker without SCC can only reconcile
2. Add SCC via PR (manual or external)
3. Worker with SCC can self-improve
4. Continuous improvement loop

---

## References

- **A-Dev Canonical**: `.adev/ADEV.md`
- **Quality Standards**: `.adev/QUALITY.md`
- **Worker Script**: `platform/scripts/homedir-sdlc-worker.sh`
- **Policy System**: `platform/config/autonomous-decision-policy.yaml`
- **Architecture**: `docs/HOMEDIR-AI-SDLC-FLOW.md`
