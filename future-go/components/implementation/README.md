# Implementation Service

Multi-pass code generation with quality-driven re-prompting for AI-SDLC.

## Overview

Implements **Implementation Iterations** (critical gap from [AI-SDLC-COMPONENTS-STATUS.md](../../homedir-infra/AI-SDLC-COMPONENTS-STATUS.md)) by adding quality validation and feedback loops before PR creation.

**Current Flow (Single-shot):**
```
Issue → SCC Generate (1 attempt) → PR → CI
```

**New Flow (Multi-pass with Quality Gates):**
```
Issue → Implementation Service
  ↓
  Loop (max 3 iterations):
    1. Generate Code (sc-agent-cli with qwen3.6)
    2. Quality Check (AI-powered review)
    3. If score ≥ 8/10 → Accept
    4. If score < 8 → Re-prompt with feedback
  ↓
  Best Attempt → PR
```

## Architecture

### Components

**1. Implementation Iterator** (`internal/implementation/iterator.go`)
- Orchestrates multi-pass generation loop
- Tracks attempts and quality scores
- Selects best code version
- Configuration: `MAX_IMPLEMENTATION_ITERATIONS`, `QUALITY_THRESHOLD`

**2. SC-Agent Client** (`internal/scagent/client.go`)
- Executes sc-agent-cli via shell
- Generation mode: Code creation from issue
- Review mode: Quality assessment of generated code
- Uses qwen3.6 model (faster response times)

**3. Quality Scorer** (`internal/quality/scorer.go`)
- Parses AI review into structured score
- Dimensions: Correctness, Completeness, Code Quality, Error Handling, Testing
- Overall score calculation (0-10)
- Issue extraction for feedback

**4. HTTP API** (`internal/implementation/http.go`)
- `POST /api/implementation/generate` - Generate code with iterations
- `GET /api/implementation/status/{id}` - Check generation status
- Request/Response models

**5. Main Service** (`cmd/main.go`)
- HTTP server setup
- Configuration loading
- Service initialization

### Data Flow

```
POST /api/implementation/generate
  ↓
ImplementationIterator.Generate()
  ↓
  Loop (attempt 1..N):
    │
    ├─> scagent.GenerateCode(issue)
    │     ↓
    │   code_v1
    │     ↓
    ├─> quality.Score(code_v1)
    │     ↓
    │   score = 6.5/10, issues: ["Missing tests", "No error handling"]
    │     ↓
    ├─> If score < 8.0:
    │     BuildFeedbackPrompt(code_v1, issues)
    │     ↓
    ├─> scagent.GenerateCode(issue + feedback)
    │     ↓
    │   code_v2
    │     ↓
    ├─> quality.Score(code_v2)
    │     ↓
    │   score = 8.5/10, issues: []
    │     ↓
    └─> score >= 8.0 → Accept code_v2
  ↓
Return: best code, quality score, iteration count
```

## API

### POST /api/implementation/generate

Generate code for an issue using multi-pass iteration with quality feedback.

**Request:**
```json
{
  "issue_number": 123,
  "issue_body": "Add user authentication feature...",
  "acceptance_criteria": [
    "Users can login with email/password",
    "JWT tokens issued on successful auth",
    "Endpoints protected with auth middleware"
  ],
  "max_iterations": 3,
  "quality_threshold": 8.0
}
```

**Response:**
```json
{
  "code": "package main\n\nimport (...)\n\nfunc main() {...}",
  "quality_score": 8.5,
  "iterations_used": 2,
  "feedback_history": [
    {
      "attempt": 1,
      "score": 6.5,
      "issues": ["Missing error handling in auth flow", "No tests for token validation"],
      "code_sample": "func Login(w http.ResponseWriter, r *http.Request) {...}"
    },
    {
      "attempt": 2,
      "score": 8.5,
      "issues": [],
      "code_sample": "func Login(w http.ResponseWriter, r *http.Request) error {...}"
    }
  ],
  "selected_attempt": 2,
  "timestamp": "2026-08-29T10:30:45Z"
}
```

### GET /api/implementation/status/{id}

Check generation status (for async implementations).

## Configuration

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `MAX_IMPLEMENTATION_ITERATIONS` | `3` | Maximum generation attempts |
| `QUALITY_THRESHOLD` | `8.0` | Minimum score to accept (0-10) |
| `SC_AGENT_PATH` | `scc` | Path to sc-agent-cli binary |
| `SC_PROFILE` | `qwen3.6` | sc-agent-cli profile to use |
| `PORT` | `8082` | HTTP server port |

**sc-agent-cli Profile:**

Required profile in `~/.config/sc-agent/profiles.json`:
```json
{
  "name": "qwen3.6",
  "baseUrl": "http://localhost:11434/v1",
  "model": "qwen3.6:latest"
}
```

## Quality Scoring

### Dimensions

Code quality assessed across 5 dimensions (each 0-10):

1. **Correctness** - Does it solve the stated problem?
2. **Completeness** - Meets all acceptance criteria?
3. **Code Quality** - Clean, readable, maintainable?
4. **Error Handling** - Proper error handling and edge cases?
5. **Testing** - Has tests covering main paths?

### Overall Score

```go
Overall = (Correctness * 0.3) + 
          (Completeness * 0.25) + 
          (CodeQuality * 0.2) + 
          (ErrorHandling * 0.15) + 
          (Testing * 0.1)
```

### Thresholds

- `≥ 8.0` → **Accept** immediately
- `6.0-7.9` → **Re-prompt** with feedback
- `< 6.0` → **Re-prompt** with detailed feedback

## Re-Prompting Strategy

When quality score is below threshold, build feedback prompt:

```
Improve previous implementation for issue #123.

Previous attempt scored 6.5/10 with these issues:
- Missing error handling in auth flow
- No tests for token validation

Original requirements:
[Issue body]

Previous code:
[Generated code from attempt N]

Generate improved version addressing all issues above.
Focus on:
1. Adding comprehensive error handling
2. Writing tests for token validation
```

AI receives:
- Original issue context
- Previous code version
- Specific quality issues found
- Target improvements

## Integration with Worker

**Worker Bash** (`platform/scripts/homedir-sdlc-worker.sh`) integration:

```bash
# In reconcile_implementing_issues()

# OLD (single-shot):
# code=$(scc_generate_code "${issue_number}")

# NEW (multi-pass with quality):
if implementation_service_available; then
  response=$(curl -X POST http://localhost:8082/api/implementation/generate \
    -H "Content-Type: application/json" \
    -d "{
      \"issue_number\": ${issue_number},
      \"issue_body\": \"${issue_body}\",
      \"acceptance_criteria\": ${criteria_json},
      \"max_iterations\": ${MAX_IMPLEMENTATION_ITERATIONS:-3},
      \"quality_threshold\": ${QUALITY_THRESHOLD:-8.0}
    }")
  
  code=$(echo "${response}" | jq -r '.code')
  quality_score=$(echo "${response}" | jq -r '.quality_score')
  iterations_used=$(echo "${response}" | jq -r '.iterations_used')
  
  log "Code generated with quality ${quality_score}/10 in ${iterations_used} iterations"
  journal "implementation_quality" "${issue_number}" "${quality_score}" "${iterations_used}"
else
  # Fallback to direct SCC (backward compatible)
  code=$(scc_generate_code "${issue_number}")
fi

# Proceed to create PR with code
create_pr "${issue_number}" "${code}"
```

## Building & Running

### Build

```bash
cd future-go/components/implementation
go mod init github.com/os-santiago/homedir-ai-sdlc/components/implementation
go mod tidy
go build -o implementation-service ./cmd
```

### Run

```bash
# Required: sc-agent-cli in PATH
which scc || echo "Install sc-agent-cli first"

# Start service
export SC_PROFILE=qwen3.6
export QUALITY_THRESHOLD=8.0
export MAX_IMPLEMENTATION_ITERATIONS=3
./implementation-service
# Listening on :8082
```

### Docker

```bash
podman build -t ai-sdlc-implementation:latest .
podman run -p 8082:8082 \
  -e SC_PROFILE=qwen3.6 \
  -v ~/.config/sc-agent:/root/.config/sc-agent:ro \
  ai-sdlc-implementation:latest
```

## Testing

### Unit Tests

```bash
go test ./internal/...
```

### Integration Test

```bash
# Start sc-agent-cli provider (Ollama with qwen3.6)
ollama run qwen3.6

# Test generation
curl -X POST http://localhost:8082/api/implementation/generate \
  -H "Content-Type: application/json" \
  -d '{
    "issue_number": 999,
    "issue_body": "Add health check endpoint at /health returning {\"status\": \"ok\"}",
    "acceptance_criteria": [
      "GET /health returns 200",
      "Response is JSON with status field"
    ],
    "max_iterations": 3,
    "quality_threshold": 8.0
  }'
```

Expected:
- Iterations: 1-2 (simple task)
- Quality score: ≥ 8.0
- Code: HTTP handler for /health endpoint

## Monitoring

### Metrics

Track in journal events:
- `implementation_quality`: Quality score per attempt
- `implementation_iterations`: Iterations used
- `implementation_accepted`: Code accepted
- `implementation_failed`: Max iterations exceeded without reaching threshold

### Logs

```bash
tail -f /var/log/homedir-sdlc/implementation-service.log
```

Log format:
```
2026-08-29T10:30:45Z INFO  [implementation] Starting generation for issue #123
2026-08-29T10:31:02Z INFO  [scagent] Generation attempt 1 completed (1847 chars)
2026-08-29T10:31:05Z INFO  [quality] Scored 6.5/10 (issues: 2)
2026-08-29T10:31:06Z INFO  [implementation] Below threshold, re-prompting with feedback
2026-08-29T10:31:23Z INFO  [scagent] Generation attempt 2 completed (2134 chars)
2026-08-29T10:31:26Z INFO  [quality] Scored 8.5/10 (issues: 0)
2026-08-29T10:31:26Z INFO  [implementation] Accepted attempt 2 with score 8.5
```

## Benefits

✅ **Higher Quality Code**: Multi-pass with AI feedback loop  
✅ **Lower CI Failures**: Pre-PR quality validation catches issues early  
✅ **Better AI Utilization**: Feedback maximizes model potential  
✅ **Reduced Human Escalation**: Auto-fix quality issues before PR  
✅ **Measurable Improvement**: Track quality scores over time  
✅ **Fast Iteration**: qwen3.6 has better response times than previous models  

## Comparison

| Metric | Before (Single-shot) | After (Multi-pass) |
|--------|---------------------|-------------------|
| **Quality Gate** | CI (post-PR) | Pre-PR validation |
| **Iterations** | 1 (fixed) | 1-3 (adaptive) |
| **Feedback Loop** | ❌ No | ✅ Yes |
| **CI Failures** | Baseline | Target: -30% |
| **`needs-human`** | Baseline | Target: -40% |
| **First-time PR Success** | Baseline | Target: +50% |

## Success Metrics (90 days)

**Target Improvements:**
- ↑ 20% average quality score (target: 8.5+)
- ↓ 30% CI failures on implementation PRs
- ↓ 40% issues marked `needs-human` during implementation
- ↑ 50% first-time PR success rate

**Tracking Query:**
```sql
SELECT 
  DATE(timestamp) as date,
  AVG(quality_score) as avg_score,
  AVG(iterations_used) as avg_iterations,
  COUNT(*) as total_generations
FROM implementation_attempts
WHERE timestamp >= NOW() - INTERVAL '90 days'
GROUP BY date
ORDER BY date DESC;
```

## References

- **Issue:** [#29 - feat: implement implementation iterations with re-prompting](https://github.com/os-santiago/homedir-ai-sdlc/issues/29)
- **Gap Analysis:** [AI-SDLC-COMPONENTS-STATUS.md](../../../homedir-infra/AI-SDLC-COMPONENTS-STATUS.md)
- **sc-agent-cli:** D:/git/sc-agent-cli
- **Loop Detection:** sc-agent-cli/docs/loop-detection.md
- **Worker Integration:** platform/scripts/homedir-sdlc-worker.sh

## Future Enhancements

- [ ] Async generation with status polling
- [ ] Code execution sandbox for validation
- [ ] Learning from past quality scores
- [ ] Dynamic threshold adjustment based on issue complexity
- [ ] A/B testing different generation strategies
- [ ] Parallel generation with voting (3 independent attempts → best of 3)

---

**Last Updated:** 2026-08-29  
**Status:** In Development  
**Closes:** [#29](https://github.com/os-santiago/homedir-ai-sdlc/issues/29)
