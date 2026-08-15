# Fix: SCC Batch Mode Not Producing Commits

## Problem Statement

The AI-SDLC worker executes SCC (Claude Code CLI) in batch mode to implement GitHub issues, but SCC frequently completes without producing any file changes, resulting in issues being marked as `needs-human` with the message:

```
SCC completed without producing any branch changes. Common causes:
- Agent responded with intent ("Now I'll...") but did not execute tools in batch mode
```

### Root Cause Analysis

**Investigation findings:**

1. **Worker creates branches correctly** ✅
   - Branch created: `scc/issue-${number}-${slug}` from `origin/main`

2. **Worker commits changes correctly** ✅
   ```bash
   if [[ -n "$(git status --porcelain)" ]]; then
       git add -A
       git commit -m "chore(sdlc): implement issue #${number}"
   fi
   ```

3. **SCC executes without errors** ✅
   - SC_MAX_ITERATIONS reduced from 100 to 10 (prevents timeout)
   - NVIDIA API configured and working

4. **The actual problem: Vague prompt** ❌

The worker's current prompt to SCC is too ambiguous for batch mode (`-yq` flag):

```bash
prompt="Implement GitHub issue #${number} in ${REPO}.

Issue title: ${title}
Issue URL: ${url}
Issue body: ${body}"
```

In batch mode, SCC interprets "Implement" as:
- "Describe how to implement" ❌
- "Plan the implementation" ❌

Instead of:
- "Execute Edit/Write tools and make changes NOW" ✅

### Reproduction

**Test case:**
- Issue #1468: Simple task to add a comment to README.md
- Expected: SCC adds comment and commits
- Actual: SCC responds with intent but doesn't execute tools

**Log evidence:**
```
23:03:42 - running SCC for issue #1468 (timeout: 300s)
23:04:18 - SCC completed (37 seconds)
Result: No file changes detected
Branch: scc/issue-1468-... exists but has no commits
```

## Solution

### Updated Prompt (Explicit Instructions)

Replace vague "Implement" with explicit batch-mode instructions:

```bash
prompt="Resolve GitHub issue #${number} by making the required code changes NOW.

CRITICAL INSTRUCTIONS FOR BATCH MODE:
- YOU MUST execute Edit/Write/Bash tools to make actual file changes
- DO NOT just describe what to do - EXECUTE the changes immediately
- Read relevant files first with Read tool, then modify them with Edit/Write
- Ensure all acceptance criteria are met with real code changes
- Work is complete only when files are modified and changes are committed

Issue title: ${title}
Issue URL: ${url}

Issue description:
${body}

Execute the implementation immediately using available tools (Read, Edit, Write, Bash)."
```

### Why This Works

1. **"NOW" creates urgency** - Forces immediate execution
2. **Explicit tool names** - Tells SCC exactly which tools to use
3. **Negative instruction** - "DO NOT just describe" prevents planning-only responses
4. **Success criteria** - "Work is complete only when files are modified"
5. **Action verbs** - "EXECUTE", "Read", "modify" instead of passive "Implement"

## Implementation

### File Modified
- `platform/scripts/homedir-sdlc-worker.sh` (line 2118)

### Testing Plan

1. **Before merge:**
   - Unit test: Verify prompt contains "EXECUTE" and "Edit/Write/Bash"
   - Integration test: Create simple issue (e.g., add comment to file)
   - Verify SCC produces file changes and commits

2. **After deploy:**
   - Monitor issues #1468-#1470 (auto-split from #1467)
   - Success metric: SCC produces commits for >80% of eligible issues
   - Fallback: Revert to previous prompt if regression detected

## Deployment Process

Following the established PR workflow:

1. ✅ **PR Created** - This fix in branch `fix/scc-batch-mode-prompt`
2. ⏳ **CI Validation** - Run tests and linters
3. ⏳ **Code Review** - Review and approve
4. ⏳ **Merge to main** - Merge PR
5. ⏳ **Deploy to VPS** - Pull from main on VPS:
   ```bash
   ssh root@vps
   cd /path/to/homedir-ai-sdlc-repo
   git pull origin main
   cp platform/scripts/homedir-sdlc-worker.sh /home/homedir-sdlc/.local/bin/
   systemctl --user restart homedir-sdlc-worker.timer
   ```

## Related Issues

- Current drift: VPS worker script (2516 lines) vs repo (2476 lines)
  - **Action required:** Sync VPS changes back to repo via PR before this fix
- Containerization needed (see separate proposal)

## Impact

**Positive:**
- Higher success rate for autonomous issue resolution
- Fewer `needs-human` false positives
- Better utilization of SCC capabilities

**Risk:**
- If prompt is too forceful, SCC might attempt changes it shouldn't
- Mitigation: Worker still validates all changes before push/PR

## Success Metrics

Monitor for 7 days after deploy:

- **Target:** Issues marked `scc-pr-open` increase by 60%+
- **Target:** Issues marked `needs-human` due to "no changes" decrease by 80%+
- **Watch:** Issues marked `scc-failed` (validation failures) - should remain stable

## References

- Investigation session: 2026-08-14
- Test issue: #1467 (auto-split to #1468, #1469, #1470)
- Worker script version: commit `8f06346`
