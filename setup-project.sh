#!/usr/bin/env bash
# Setup complete GitHub project for AI-SDLC Autonomy Roadmap
# This script creates milestones, labels, epic issues, and Week 1 issues

set -euo pipefail

REPO="os-santiago/homedir-ai-sdlc"

echo "🚀 Setting up AI-SDLC Autonomy Project..."
echo ""

# ============================================================================
# 1. CREATE MILESTONES
# ============================================================================
echo "📅 Creating milestones..."

gh milestone create "Week 1: Foundation & Quick Win" \
  --repo "${REPO}" \
  --due 2026-08-31 \
  --description "Recovery of SCC in K3s + Context Engineering foundation + 70% autonomy. Goal: Deploy SCC, implement basic context engineering, complete 1 medium issue E2E."

gh milestone create "Week 2: Validation & Learning" \
  --repo "${REPO}" \
  --due 2026-09-07 \
  --description "E2E test with real medium complexity issue. Measure autonomy improvement. Refine context engineering based on gaps identified."

gh milestone create "Week 3-4: Multi-Step Planning" \
  --repo "${REPO}" \
  --due 2026-09-21 \
  --description "Planning agent implementation. DAG-based task execution. Dependency resolution. Handle issues with 5-7 files through decomposition into simple subtasks."

gh milestone create "Week 5: Mid-Project Validation" \
  --repo "${REPO}" \
  --due 2026-09-28 \
  --description "E2E tests with 2 complex real issues. Compare metrics vs baseline. Identify next bottleneck. Adjust roadmap if needed."

gh milestone create "Week 6-7: Auto-Correction & Quality Gates" \
  --repo "${REPO}" \
  --due 2026-10-12 \
  --description "Self-review mechanism. Iterative refinement loop. 8 levels of quality gates. Acceptance criteria validation with SCC. Code auto-corrects until passing gates."

gh milestone create "Week 8: Knowledge Management" \
  --repo "${REPO}" \
  --due 2026-10-19 \
  --description "Decision log infrastructure. Pattern/anti-pattern extraction. Context templates library. E2E with high complexity issue. System learns from every execution."

echo "✅ Milestones created"
echo ""

# ============================================================================
# 2. CREATE LABELS
# ============================================================================
echo "🏷️  Creating labels..."

# Type labels
gh label create "feature" --repo "${REPO}" --color "0E8A16" --description "New functionality" --force
gh label create "bug" --repo "${REPO}" --color "D73A4A" --description "Error correction" --force
gh label create "refactor" --repo "${REPO}" --color "FBCA04" --description "Code improvement" --force
gh label create "documentation" --repo "${REPO}" --color "0075CA" --description "Documentation changes" --force
gh label create "testing" --repo "${REPO}" --color "BFD4F2" --description "Test additions/improvements" --force

# Epic labels
gh label create "epic" --repo "${REPO}" --color "3E4B9E" --description "Parent issue grouping others" --force
gh label create "context-engineering" --repo "${REPO}" --color "5319E7" --description "Epic #1: Context Engineering" --force
gh label create "multi-step-planning" --repo "${REPO}" --color "5319E7" --description "Epic #2: Multi-Step Planning" --force
gh label create "auto-correction" --repo "${REPO}" --color "5319E7" --description "Epic #3: Iterative Refinement" --force
gh label create "quality-gates" --repo "${REPO}" --color "5319E7" --description "Epic #4: Quality Gates" --force
gh label create "knowledge-management" --repo "${REPO}" --color "5319E7" --description "Epic #5: Knowledge Management" --force

# AI-SDLC state labels (some may already exist)
gh label create "ready-to-implement" --repo "${REPO}" --color "0E8A16" --description "Ready for AI-SDLC" --force || true
gh label create "scc-queued" --repo "${REPO}" --color "FBCA04" --description "In SCC queue" --force || true
gh label create "scc-running" --repo "${REPO}" --color "FF9800" --description "SCC executing" --force || true
gh label create "scc-pr-open" --repo "${REPO}" --color "1D76DB" --description "PR created by SCC" --force || true
gh label create "scc-merged" --repo "${REPO}" --color "0E8A16" --description "Merged successfully" --force || true
gh label create "needs-human" --repo "${REPO}" --color "D93F0B" --description "Requires human intervention" --force || true

# Priority labels
gh label create "P0-blocker" --repo "${REPO}" --color "B60205" --description "Blocks everything" --force
gh label create "P1-high" --repo "${REPO}" --color "D93F0B" --description "High priority" --force
gh label create "P2-medium" --repo "${REPO}" --color "FBCA04" --description "Medium priority" --force
gh label create "P3-low" --repo "${REPO}" --color "0E8A16" --description "Low priority" --force

# Complexity labels
gh label create "complexity-low" --repo "${REPO}" --color "C2E0C6" --description "1-3 files" --force
gh label create "complexity-medium" --repo "${REPO}" --color "FEF2C0" --description "4-7 files" --force
gh label create "complexity-high" --repo "${REPO}" --color "F9D0C4" --description "8+ files" --force

echo "✅ Labels created"
echo ""

# ============================================================================
# 3. CREATE EPIC ISSUES
# ============================================================================
echo "📝 Creating epic issues..."

# Epic #1: Context Engineering
gh issue create --repo "${REPO}" \
  --title "Epic: Context Engineering - Multi-level context for SCC" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "epic,context-engineering,feature,P1-high" \
  --body "## Epic #1: Context Engineering

**Milestone**: Week 1-2
**Estimated**: 40 hours
**Owner**: scanales-stack

### Objective
Implement multi-level context construction system for SCC to provide 10x more context than currently available.

### Components
1. Impact analyzer (identify affected areas)
2. File context grabber (extract relevant files)
3. Architecture context (project patterns)
4. Decision log searcher (past decisions)
5. Context bundle builder (consolidate all)

### Child Issues
- #TBD: Implement impact analyzer
- #TBD: Implement file context grabber
- #TBD: Add architecture context
- #TBD: Implement decision log searcher
- #TBD: Create context bundle builder
- #TBD: Testing with real issue

### Acceptance Criteria
- [ ] SCC receives 10x more context than currently
- [ ] Context includes: affected files, patterns, past decisions
- [ ] Context construction time < 30 seconds
- [ ] Documented in platform/docs/context-engineering.md
- [ ] At least 1 medium complexity issue completed with improved context
- [ ] Measurable improvement in SCC output quality

### Success Metrics
- Context bundle size: 50-100KB
- Construction time: < 30s
- SCC accuracy improvement: >= 50%
"

# Epic #2: Multi-Step Planning
gh issue create --repo "${REPO}" \
  --title "Epic: Multi-Step Planning - DAG-based task decomposition" \
  --milestone "Week 3-4: Multi-Step Planning" \
  --label "epic,multi-step-planning,feature,P1-high" \
  --body "## Epic #2: Multi-Step Planning

**Milestone**: Week 3-4
**Estimated**: 60 hours
**Owner**: scanales-stack

### Objective
Decompose complex issues into DAG of executable subtasks with dependency resolution.

### Components
1. Planning agent (generates DAG)
2. Task dependency resolver
3. Task executor (in-order execution)
4. Human review checkpoints
5. Task validation
6. Progress tracking

### Child Issues
- #TBD: Implement planning agent
- #TBD: Create task dependency resolver
- #TBD: Implement task executor
- #TBD: Add human review checkpoints
- #TBD: Implement task validation
- #TBD: Test with 7-file issue

### Acceptance Criteria
- [ ] Complex issues decomposed into < 2 file tasks
- [ ] DAG respects dependencies (DB → backend → frontend)
- [ ] Human review only at strategic checkpoints
- [ ] Logging of each phase execution
- [ ] Documented in platform/docs/multi-step-planning.md
- [ ] At least 1 high complexity issue completed via planning

### Success Metrics
- Average subtask size: 1-2 files
- Planning time: < 2 minutes
- Execution success rate: >= 80%
"

# Epic #3: Iterative Refinement
gh issue create --repo "${REPO}" \
  --title "Epic: Iterative Refinement - Self-review and auto-correction" \
  --milestone "Week 6-7: Auto-Correction & Quality Gates" \
  --label "epic,auto-correction,feature,P1-high" \
  --body "## Epic #3: Iterative Refinement

**Milestone**: Week 6-7
**Estimated**: 50 hours
**Owner**: scanales-stack

### Objective
Auto-correction through self-review until quality gates pass (max 3 iterations).

### Components
1. Self-review mechanism (SCC reviews own code)
2. Issue extractor (from review results)
3. Refinement loop (max 3 iterations)
4. Convergence detection
5. Iteration logging

### Child Issues
- #TBD: Implement self-review mechanism
- #TBD: Create issue extractor
- #TBD: Implement refinement loop
- #TBD: Add convergence detection
- #TBD: Iteration logging
- #TBD: Test auto-correction vs manual

### Acceptance Criteria
- [ ] Self-review identifies >= 80% of obvious issues
- [ ] Refinement converges in <= 3 iterations (90% of cases)
- [ ] Logging shows progress of each iteration
- [ ] Documented in platform/docs/iterative-refinement.md
- [ ] Measurable improvement after each iteration

### Success Metrics
- Self-review accuracy: >= 80%
- Convergence rate: >= 90% within 3 iterations
- Final quality score: >= 85/100
"

# Epic #4: Quality Gates Automation
gh issue create --repo "${REPO}" \
  --title "Epic: Quality Gates - 8 levels of automated validation" \
  --milestone "Week 6-7: Auto-Correction & Quality Gates" \
  --label "epic,quality-gates,feature,P1-high" \
  --body "## Epic #4: Quality Gates Automation

**Milestone**: Week 6-7
**Estimated**: 40 hours
**Owner**: scanales-stack

### Objective
Implement 8 levels of automated quality validation.

### Quality Gates
1. Build verification
2. Unit tests
3. Integration tests
4. Coverage threshold (>= 80%)
5. Static analysis
6. Security scan
7. Performance regression
8. Acceptance criteria validation (SCC-based)

### Child Issues
- #TBD: Gates 1-2 (Build + Unit tests)
- #TBD: Gates 3-4 (Integration + Coverage)
- #TBD: Gates 5-6 (Static analysis + Security)
- #TBD: Gate 7 (Performance regression)
- #TBD: Gate 8 (Acceptance criteria)
- #TBD: Implement gate runner
- #TBD: Reporting system

### Acceptance Criteria
- [ ] All 8 gates implemented and documented
- [ ] Parallel execution of independent gates
- [ ] Informative failures with fix suggestions
- [ ] Pass rate metrics per gate
- [ ] Documented in platform/docs/quality-gates.md

### Success Metrics
- Gate execution time: < 5 minutes total
- Overall pass rate: >= 95%
- False positive rate: < 5%
"

# Epic #5: Knowledge Management
gh issue create --repo "${REPO}" \
  --title "Epic: Knowledge Management - Continuous learning from decisions" \
  --milestone "Week 8: Knowledge Management" \
  --label "epic,knowledge-management,feature,P2-medium" \
  --body "## Epic #5: Knowledge Management

**Milestone**: Week 8
**Estimated**: 30 hours
**Owner**: scanales-stack

### Objective
System learns continuously from past decisions, patterns, and anti-patterns.

### Components
1. Knowledge base structure
2. Decision logger
3. Decision searcher
4. Pattern extractor
5. Anti-pattern detector
6. Prompt enrichment

### Child Issues
- #TBD: Create knowledge/ structure
- #TBD: Implement decision logger
- #TBD: Implement decision searcher
- #TBD: Create pattern extractor
- #TBD: Implement anti-pattern detector
- #TBD: Enrich prompts with knowledge

### Acceptance Criteria
- [ ] Every architectural decision logged automatically
- [ ] Search of past decisions < 2 seconds
- [ ] Patterns/anti-patterns extracted from >= 10 PRs
- [ ] Prompts enriched with relevant knowledge
- [ ] Documented in platform/docs/knowledge-management.md

### Success Metrics
- Knowledge base size: >= 20 decisions after Week 8
- Search relevance: >= 80%
- Prompt enrichment usage: 100% of issues
"

echo "✅ Epic issues created"
echo ""

# ============================================================================
# 4. CREATE WEEK 1 ISSUES
# ============================================================================
echo "📋 Creating Week 1 issues..."

# Issue #1 (corresponds to #115 in plan)
gh issue create --repo "${REPO}" \
  --title "Create and merge PR for SCC workflow build" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "feature,P0-blocker,complexity-low,ready-to-implement" \
  --body "## Description
Create PR manually for the SCC workflow that enables worker container to include sc-agent-cli.

## Context
GitHub API rate limit prevented automatic PR creation. Branch \`feat/add-worker-image-build-workflow\` already exists with the workflow file.

## Files Affected
- \`.github/workflows/build-worker-image.yml\`

## Acceptance Criteria
- [ ] PR created at https://github.com/os-santiago/homedir-ai-sdlc/pull/new/feat/add-worker-image-build-workflow
- [ ] PR title: \"feat: add CI/CD workflow to build worker image with SCC\"
- [ ] PR description references this issue
- [ ] CI checks pass
- [ ] PR merged to main
- [ ] GitHub Actions build triggered
- [ ] Image with SCC published to ghcr.io

## Complexity
Low (1 file, manual PR creation)

## Priority
P0 (Blocker) - Blocks all autonomy improvements

## Type
Feature

## Dependencies
None - this is the foundation
"

# Issue #2 (corresponds to #116 in plan)
gh issue create --repo "${REPO}" \
  --title "Verify SCC functionality in K3s logs" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "testing,P0-blocker,complexity-low" \
  --body "## Description
Validate that K3s auto-pulls the new worker image with SCC and that SCC executes successfully.

## Context
After PR merge and image build, K3s CronJob should auto-pull the new image on next execution (~3 minutes). We need to verify SCC is found and functional.

## Acceptance Criteria
- [ ] K3s CronJob executes (check with kubectl get cronjob)
- [ ] Logs show \"SCC found at /usr/local/bin/scc\"
- [ ] SCC version displayed in logs
- [ ] Test execution with simple SCC command succeeds
- [ ] Autonomy metric increases from 0% to >= 70%
- [ ] Heartbeat shows worker active with SCC

## Complexity
Low (log verification)

## Priority
P0 (Blocker) - Validates foundation works

## Type
Testing

## Dependencies
Blocked by: #TBD (Create PR for SCC workflow)
"

# Issue #3 (corresponds to #117 in plan)
gh issue create --repo "${REPO}" \
  --title "Implement impact analyzer for context engineering" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "feature,context-engineering,P1-high,complexity-medium" \
  --body "## Description
Implement \`analyze_issue_impact()\` function that uses SCC to analyze issue body and determine affected areas.

## Context
Part of Epic #1: Context Engineering. This is the first step in building context bundles - understanding what areas of the codebase will be affected.

## Files Affected
- \`platform/scripts/context-builder.sh\` (new file)

## Acceptance Criteria
- [ ] Function \`analyze_issue_impact()\` created
- [ ] Uses SCC for semantic analysis of issue body
- [ ] Output JSON with: layers, components, files_likely_affected, confidence
- [ ] Timeout: 60 seconds max
- [ ] Tests with 3 different issue examples (low, medium, high complexity)
- [ ] Documentation in platform/docs/context-engineering.md
- [ ] Logs execution time and confidence score

## Example Output
\`\`\`json
{
  \"layers\": [\"backend\", \"frontend\", \"database\"],
  \"components\": [\"auth\", \"user-service\", \"ui-login\"],
  \"files_likely_affected\": [\"src/auth/*.java\", \"ui/login/*.tsx\"],
  \"external_dependencies\": [\"OAuth2 library\"],
  \"confidence\": 0.85
}
\`\`\`

## Complexity
Medium (new functionality, SCC integration)

## Priority
P1 (High) - Foundation of context engineering

## Type
Feature

## Epic
#TBD (Epic: Context Engineering)

## Dependencies
Blocked by: #TBD (Verify SCC in K3s)
"

# Issue #4 (corresponds to #118 in plan)
gh issue create --repo "${REPO}" \
  --title "Implement file context grabber" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "feature,context-engineering,P1-high,complexity-low" \
  --body "## Description
Implement \`grab_file_context()\` function that extracts content from files matching patterns.

## Context
Part of Epic #1: Context Engineering. Once we know which files are affected (from impact analyzer), we need to grab their content.

## Files Affected
- \`platform/scripts/context-builder.sh\`

## Acceptance Criteria
- [ ] Function \`grab_file_context()\` created
- [ ] Supports glob patterns (e.g., \`src/auth/*.java\`)
- [ ] Handles non-existent files gracefully (no crash)
- [ ] Limits total size (max 50KB of context)
- [ ] Returns file paths + content
- [ ] Logs number of files grabbed and total size

## Complexity
Low (file operations)

## Priority
P1 (High) - Core context functionality

## Type
Feature

## Epic
#TBD (Epic: Context Engineering)

## Dependencies
None (can work in parallel with impact analyzer)
"

# Issue #5 (corresponds to #119 in plan)
gh issue create --repo "${REPO}" \
  --title "Add architecture context document" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "documentation,context-engineering,P2-medium,complexity-low" \
  --body "## Description
Create architecture context document with project patterns, conventions, and tech stack.

## Context
Part of Epic #1: Context Engineering. Static context that describes \"how we do things\" in this project.

## Files Affected
- \`platform/config/architecture-context.md\` (new file)
- \`platform/scripts/context-builder.sh\` (add \`get_architecture_context()\`)

## Acceptance Criteria
- [ ] Document created with sections:
  - Naming conventions
  - File structure
  - Tech stack (languages, frameworks)
  - Code patterns (how we structure services, controllers, etc.)
  - Testing patterns
- [ ] Function \`get_architecture_context()\` reads document
- [ ] Context size <= 5KB
- [ ] Markdown format, easily readable

## Complexity
Low (documentation)

## Priority
P2 (Medium) - Helpful but not blocking

## Type
Documentation

## Epic
#TBD (Epic: Context Engineering)
"

# Issue #6 (corresponds to #120 in plan)
gh issue create --repo "${REPO}" \
  --title "Implement decision log searcher" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "feature,context-engineering,P1-high,complexity-medium" \
  --body "## Description
Implement \`search_decision_log()\` function to find relevant past decisions.

## Context
Part of Epic #1: Context Engineering. Search knowledge base for decisions related to current issue.

## Files Affected
- \`platform/scripts/decision-logger.sh\` (new file)
- Create \`/var/lib/homedir-sdlc/knowledge/decisions/\` directory structure

## Acceptance Criteria
- [ ] Function \`search_decision_log()\` created with keyword search
- [ ] Searches in \`/var/lib/homedir-sdlc/knowledge/decisions/\`
- [ ] Returns top 3 most relevant decisions (JSON format)
- [ ] Performance < 2 seconds
- [ ] Handles empty knowledge base gracefully
- [ ] Logs number of decisions searched and matches found

## Example Decision Format
\`\`\`json
{
  \"id\": \"2026-08-01-auth-oauth\",
  \"timestamp\": \"2026-08-01T10:30:00Z\",
  \"issue_number\": 1550,
  \"type\": \"architecture\",
  \"decision\": {
    \"description\": \"Use Spring Security OAuth2 for authentication\",
    \"reasoning\": \"...\",
    \"alternatives_considered\": [\"...\"]
  },
  \"outcome\": \"success\"
}
\`\`\`

## Complexity
Medium (search functionality, JSON handling)

## Priority
P1 (High) - Key for learning

## Type
Feature

## Epic
#TBD (Epic: Context Engineering)
"

# Issue #7 (corresponds to #121 in plan)
gh issue create --repo "${REPO}" \
  --title "Create context bundle builder" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "feature,context-engineering,P1-high,complexity-medium" \
  --body "## Description
Implement \`build_context_bundle()\` function that consolidates all context sources into one bundle.

## Context
Part of Epic #1: Context Engineering. This is the orchestrator that combines impact analysis, file content, architecture context, and past decisions.

## Files Affected
- \`platform/scripts/context-builder.sh\`

## Acceptance Criteria
- [ ] Function \`build_context_bundle()\` created
- [ ] Integrates:
  - Impact analysis results
  - File content (from grab_file_context)
  - Architecture context
  - Past decisions (from search_decision_log)
- [ ] Output: \`/tmp/context-bundle-\${issue_number}.md\`
- [ ] Total size <= 100KB
- [ ] Construction time <= 30 seconds
- [ ] Well-formatted markdown (sections, headers)
- [ ] Logs bundle size and construction time

## Bundle Structure
\`\`\`markdown
# Context Bundle for Issue #X

## Impact Analysis
[results from analyze_issue_impact]

## Affected Files
[content from grab_file_context]

## Architecture Patterns
[content from get_architecture_context]

## Past Related Decisions
[results from search_decision_log]

## Issue Details
[original issue body]
\`\`\`

## Complexity
Medium (integration of multiple functions)

## Priority
P1 (High) - Final piece of context engineering

## Type
Feature

## Epic
#TBD (Epic: Context Engineering)

## Dependencies
Blocked by:
- #TBD (Impact analyzer)
- #TBD (File grabber)
- #TBD (Decision log searcher)
"

# Issue #8 (corresponds to #122 in plan)
gh issue create --repo "${REPO}" \
  --title "Test context engineering with real medium complexity issue" \
  --milestone "Week 1: Foundation & Quick Win" \
  --label "testing,context-engineering,P1-high,complexity-medium" \
  --body "## Description
Validate context engineering system with a real medium complexity issue (4-5 files).

## Context
End-to-end test of Epic #1: Context Engineering. Select a real issue, generate context bundle, execute SCC with enriched context, compare quality vs baseline.

## Acceptance Criteria
- [ ] Real issue selected (4-5 files, medium complexity)
- [ ] Context bundle generated successfully
- [ ] Bundle reviewed for quality (has relevant context?)
- [ ] SCC executed with context bundle
- [ ] SCC output quality compared to baseline (without context)
- [ ] Results documented in platform/docs/context-engineering-results.md
- [ ] Metrics captured:
  - Bundle construction time
  - Bundle size
  - SCC execution time
  - SCC output quality score (subjective 0-100)
  - Autonomy improvement (%)

## Success Criteria
- [ ] Context bundle construction < 30s
- [ ] SCC quality improvement >= 50% vs baseline
- [ ] Issue completed successfully with context

## Complexity
Medium (E2E test)

## Priority
P1 (High) - Validates entire Epic #1

## Type
Testing

## Epic
#TBD (Epic: Context Engineering)

## Dependencies
Blocked by:
- #TBD (Context bundle builder)
"

echo "✅ Week 1 issues created"
echo ""

# ============================================================================
# SUMMARY
# ============================================================================
echo "🎉 Project setup complete!"
echo ""
echo "Created:"
echo "  - 6 milestones (8 weeks)"
echo "  - 25+ labels (types, epics, states, priorities, complexities)"
echo "  - 5 epic issues"
echo "  - 8 Week 1 issues"
echo ""
echo "Next steps:"
echo "  1. Review issues in GitHub"
echo "  2. Create GitHub Project board manually"
echo "  3. Link issues to project"
echo "  4. Start with first issue (Create PR for SCC workflow)"
echo ""
echo "View project: https://github.com/${REPO}/issues"
