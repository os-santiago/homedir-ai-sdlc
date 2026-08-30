# Pending Tasks for End-to-End AI-SDLC Testing

## Critical Blockers (Must Fix Before E2E Test)

### 1. Fix Container Build Failures

**Status:** 🔴 BLOCKING  
**Issue:** Build failures in GitHub Actions deployment  
**Impact:** Cannot deploy to VPS, no containers running

**Failed Jobs:**
- ❌ Build Worker Container
- ❌ Build Implementation Container  
- ✅ Build Dashboard Container (passing)

**Actions Required:**
1. Investigate build logs for Worker and Implementation containers
2. Fix Dockerfile/Containerfile issues
3. Re-run deployment workflow
4. Verify all 3 containers deploy successfully to VPS

**References:**
- Deployment run: #33292893477
- Related issues: #31 (deployment authentication)

---

### 2. Integrate Implementation Service with Worker

**Status:** 🟡 HIGH PRIORITY  
**Issue:** Worker currently calls `scc` directly, needs to call Implementation HTTP service  
**Impact:** Cannot test iterative code generation with quality feedback

**Current State:**
```bash
# Worker calls SCC directly (platform/scripts/homedir-sdlc-worker.sh line 400)
timeout "${dynamic_timeout}s" "${SCC_BIN}" "${scc_args[@]}"
```

**Target State:**
```bash
# Worker calls Implementation service HTTP API
curl -X POST http://localhost:8082/api/implementation/generate \
  -H "Content-Type: application/json" \
  -d '{
    "issue_number": 123,
    "issue_body": "...",
    "acceptance_criteria": [...],
    "max_iterations": 3,
    "quality_threshold": 8.0
  }'
```

**Actions Required:**
1. Create `platform/scripts/implementation-client.sh`
   - HTTP client wrapper for implementation service
   - Fallback to direct SCC if service unavailable
   - Parse JSON response and extract code

2. Modify `platform/scripts/homedir-sdlc-worker.sh`
   - Add environment variable: `IMPLEMENTATION_SERVICE_URL` (default: http://localhost:8082)
   - Replace direct SCC calls with implementation client
   - Handle service failures gracefully

3. Add service discovery
   - Worker should detect if implementation service is available
   - Log which method is being used (service vs direct SCC)

**Implementation Plan:**
```bash
# New function in homedir-sdlc-worker.sh
call_implementation_service() {
  local issue_number="$1"
  local issue_body="$2"
  local acceptance_criteria="$3"
  
  local service_url="${IMPLEMENTATION_SERVICE_URL:-http://localhost:8082}"
  
  # Check if service is available
  if ! curl -sf "${service_url}/health" >/dev/null 2>&1; then
    log "WARN: Implementation service not available, falling back to direct SCC"
    return 1
  fi
  
  log "INFO: Calling implementation service for issue #${issue_number}"
  
  local response
  response=$(curl -sf -X POST "${service_url}/api/implementation/generate" \
    -H "Content-Type: application/json" \
    -d "$(jq -n \
      --arg num "$issue_number" \
      --arg body "$issue_body" \
      --argjson criteria "$acceptance_criteria" \
      '{
        issue_number: ($num | tonumber),
        issue_body: $body,
        acceptance_criteria: $criteria,
        max_iterations: 3,
        quality_threshold: 8.0
      }')")
  
  # Extract code from response
  echo "$response" | jq -r '.code'
}
```

---

### 3. Configure VPS Secrets

**Status:** 🟡 REQUIRED  
**Issue:** VPS needs environment file with secrets  
**Impact:** Worker/Implementation cannot authenticate to GitHub/LLM APIs

**Required in `/etc/homedir-sdlc/worker.env`:**
```bash
GH_TOKEN=<github_token_with_repo_access>
NVIDIA_API_KEY=<api_key_for_qwen_model>
HOMEDIR_SDLC_REPO=os-santiago/homedir
HOMEDIR_SDLC_STATE_DIR=/var/lib/homedir-sdlc
HOMEDIR_SDLC_WORKDIR=/srv/homedir-sdlc/worktrees/homedir
HOMEDIR_SDLC_INTERVAL=180
IMPLEMENTATION_SERVICE_URL=http://localhost:8082
SC_PROFILE=qwen
```

**Actions Required:**
1. Verify GitHub Actions secrets are configured
2. Ensure deployment script writes secrets to VPS
3. Test that containers can read environment file

---

## Medium Priority (Enhance E2E Experience)

### 4. Add Implementation Service Metrics

**Status:** 🟢 NICE TO HAVE  
**Issue:** No visibility into implementation service performance

**Add Endpoints:**
- `GET /metrics` - Prometheus-style metrics
  - `implementation_requests_total{status="success|failure"}`
  - `implementation_iterations_histogram`
  - `implementation_quality_score_histogram`
  - `implementation_duration_seconds`

- `GET /api/implementation/stats` - JSON stats
  ```json
  {
    "total_requests": 42,
    "success_rate": 0.85,
    "avg_iterations": 1.8,
    "avg_quality_score": 8.3,
    "avg_duration_seconds": 45.2
  }
  ```

**Integration:**
- Dashboard can poll `/api/implementation/stats` and display

---

### 5. Worker Service Discovery

**Status:** 🟢 ENHANCEMENT  
**Issue:** Worker should auto-discover implementation service

**Current:** Hardcoded `http://localhost:8082`  
**Better:** Service discovery within pod

```bash
# Check if implementation container is running in pod
if podman ps --pod ai-sdlc --format '{{.Names}}' | grep -q ai-sdlc-implementation; then
  IMPLEMENTATION_SERVICE_URL="http://localhost:8082"
else
  log "WARN: Implementation service not running in pod, using direct SCC"
  IMPLEMENTATION_SERVICE_URL=""
fi
```

---

### 6. Dashboard Real-Time Updates

**Status:** 🟢 ENHANCEMENT  
**Issue:** Dashboard shows static data, not real-time updates

**Add WebSocket/SSE:**
- Worker publishes events to event stream
- Dashboard subscribes and updates UI live
- Show "Implementation in progress..." with iteration count

---

## Low Priority (Future Improvements)

### 7. E2E Test Automation

**Status:** 🟢 FUTURE  
**Issue:** E2E test is manual, should be automated

**Create:** `tests/e2e/test-ai-sdlc-workflow.sh`
```bash
#!/bin/bash
# Automated E2E test
# 1. Create test issue
# 2. Wait for worker cycle (max 5min)
# 3. Verify PR created
# 4. Cleanup test issue/PR
# Exit 0 if pass, 1 if fail
```

**Run in CI:** Weekly scheduled workflow

---

### 8. Multi-Issue Parallelism

**Status:** 🟢 FUTURE  
**Issue:** Worker processes 1 issue at a time

**Enhancement:** Process N issues in parallel (default 3)
- Separate worktrees for each issue
- Parallel implementation service calls
- Avoid conflicts with different branches

---

### 9. Quality Score Tuning

**Status:** 🟢 OPTIMIZATION  
**Issue:** Default threshold 8.0 may be too high/low

**Actions:**
- Collect quality scores over 30 days
- Analyze distribution
- Tune threshold based on actual success rate
- Make threshold configurable per issue complexity

---

## Verification Checklist

Before declaring E2E ready:

- [ ] **All containers build successfully** (Worker, Dashboard, Implementation)
- [ ] **All containers running on VPS** (pod ai-sdlc with 3 containers)
- [ ] **Worker integrates with Implementation service** (HTTP calls instead of direct SCC)
- [ ] **Secrets configured on VPS** (/etc/homedir-sdlc/worker.env)
- [ ] **Heartbeat updating** (/var/lib/homedir-sdlc/heartbeat.json)
- [ ] **Dashboard accessible** (https://homedir-ai-sdlc.opensourcesantiago.io)
- [ ] **Implementation service health check passing** (curl localhost:8082/health)
- [ ] **Manual E2E test passes** (issue → worker → implementation → PR)

---

## Timeline Estimate

**Critical Blockers:** 2-4 hours
- Fix builds: 1-2 hours
- Worker integration: 1-2 hours

**Medium Priority:** 2-3 hours
- Metrics: 1 hour
- Service discovery: 1 hour
- Dashboard updates: 1 hour

**Total to E2E ready:** ~4-6 hours of focused development

---

**Last Updated:** 2026-08-30  
**Next Review:** After deployment fixes complete
