# Claude Code - A-Dev Framework Auto-Load
## Initialization Instructions for All Homedir Repositories

This file is read automatically by Claude Code when working in this repository.

---

## 📚 Load A-Dev Governance (MANDATORY)

Before starting ANY work in this repository, you MUST load the A-Dev framework:

### 1. Read Canonical Doctrine
```
Read .adev/ADEV.md
```
This is the **canonical operating doctrine** from A-Dev framework.

### 2. Read Quality Standards
```
Read .adev/QUALITY.md
```
This defines the 50/50 quality ritual: Build → Run → Walkthrough → Evidence.

### 3. Read Repo-Specific Extensions
```
Read ADEV-LOCAL.md
```
This contains local extensions specific to this repository.

### 4. Parse Configuration
```
Read .adev-config.yaml
```
This defines enforcement rules, labels, and cross-repo standards.

---

## 🎯 Mandatory Constraints (from A-Dev)

### Branch Workflow
- ✅ **Branch-per-change** workflow mandatory
- ❌ **Never commit directly** to main branch
- ✅ All commits use **Conventional Commits** format
- ✅ All PRs **link to issues** (`Closes #123`)

### No Scope Mixing
- ❌ Do NOT combine: feature + refactor in same PR
- ❌ Do NOT combine: feature + docs in same PR
- ❌ Do NOT combine: bug fix + infrastructure in same PR
- ✅ Separate PRs by type unless batch delivery explicitly requested

### Quality Ritual (50/50)
1. **Build**: Local compilation, feature toggles (not heavy staging)
2. **Run**: Automated tests, security checks, health endpoints
3. **Walkthrough**: Persona-based validation, does it meet the need?
4. **Evidence**: Commit, CI pipeline green, docs updated

Target: **5-10 minutes for full QA loop**

### Never Commit
- ❌ API keys, passwords, tokens, credentials, connection strings
- ❌ Real names, emails, phone numbers, company names (anonymize)
- ❌ Secrets of any kind

### Collaboration Protocol
1. **Situational awareness first**: Inspect branch, working tree before editing
2. **Never overwrite unreviewed local work**
3. **Document all decisions** in ADRs or ADEV-LOCAL.md
4. **Clean up temporary files** after task completion

### Librarian Discipline
- **Search before adding**: Use grep/glob to find existing content
- **Consolidate**: Merge into existing docs/functions
- **Create new** only when genuinely distinct

---

## 🏗️ Repository-Specific Behavior

The behavior varies based on which repository you're in:

### If in `homedir/`:
- Technology: Java 21 + Quarkus 3.16
- Quality gates: `mvn clean test`, integration tests, E2E walkthrough
- I18n mandatory: pt-BR, en-US, es-ES
- Database migrations must be backward compatible
- See `ADEV-LOCAL.md` for specific patterns

### If in `homedir-ai-sdlc/`:
- Technology: Bash + SCC (sc-agent-cli)
- Quality gates: shellcheck, container build, E2E issue→PR flow
- Worker must be idempotent
- State files are source of truth
- See `ADEV-LOCAL.md` for worker patterns

### If in `homedir-infra/`:
- Technology: Markdown (docs only)
- Quality gates: link validation, YAML syntax, readability
- This is the **governance hub**
- See `ADEV-LOCAL.md` for sync protocols

---

## ✅ Pre-Work Checklist

Before starting ANY task, verify:

- [ ] Read `.adev/ADEV.md` (canonical doctrine)
- [ ] Read `.adev/QUALITY.md` (quality standards)
- [ ] Read `ADEV-LOCAL.md` (repo-specific)
- [ ] Read `.adev-config.yaml` (enforcement rules)
- [ ] Understand: Is this feature? bug fix? docs? refactor?
- [ ] Check: Am I mixing scopes? (if yes, split into separate PRs)
- [ ] Plan: Build → Run → Walkthrough → Evidence
- [ ] Verify: No secrets will be committed

---

## 🚫 Common Mistakes to Avoid

1. **Starting work without reading A-Dev doctrine** → Read it FIRST
2. **Committing directly to main** → Create branch
3. **Mixing feature + refactor** → Separate PRs
4. **Skipping quality ritual** → Build, Run, Walkthrough, Evidence
5. **Committing secrets** → Check before commit
6. **Creating duplicate content** → Search first (librarian)
7. **Temporary files left behind** → Clean up after task

---

## 📖 Decision Making

When you encounter a decision point:

1. **Check A-Dev doctrine** first (`.adev/ADEV.md`)
2. **Check repo-specific doctrine** (`ADEV-LOCAL.md`)
3. **Check configuration** (`.adev-config.yaml`)
4. If not covered: **Ask user** or **Document new pattern**

---

## 🔄 Continuous Improvement

When you learn something new or encounter a failure:

1. **Update doctrine** if pattern should be preserved
2. **Document decision** in ADR or ADEV-LOCAL.md
3. **Link to evidence** (issue, PR, incident)
4. **Create PR** with doctrine update

---

## 🎓 Learning from Failures

If a task fails or produces unexpected results:

1. **Analyze root cause**
2. **Check if doctrine would have prevented it**
3. **Propose doctrine update** if pattern should be codified
4. **PR the update** with link to failure evidence

---

## 📝 Session Handoff

If you need to hand off work mid-session:

1. **Update HANDOFF.md** (if exists) or **SESSION-LOG.md**
2. **Document current state**: branch, what's done, what's next
3. **List blockers** if any
4. **Commit work-in-progress** to branch (not main)

---

## 🌟 Excellence Standard

The A-Dev framework emphasizes:

> "The strongest material in this system is disciplined learning under failure, delivery pressure, and verification, not abstract optimism."

This means:
- **Learn from failures**, don't hide them
- **Document lessons**, don't repeat mistakes
- **Evidence over theory**, show don't tell
- **Incremental delivery**, not big-bang

---

## ⚡ Quick Reference

| Question | Answer |
|----------|--------|
| Can I commit to main? | ❌ No, always branch-per-change |
| Can I mix feature + refactor? | ❌ No, separate PRs |
| Do I need tests? | ✅ Yes, part of quality ritual |
| What's the quality cycle? | Build → Run → Walkthrough → Evidence (50/50) |
| Where do I document decisions? | ADEV-LOCAL.md or docs/decisions/ |
| Can I commit secrets? | ❌ Never, anonymize everything |
| Should I search before adding? | ✅ Yes, librarian discipline |

---

## 🔗 Key Files

- **`.adev/ADEV.md`** - Canonical doctrine (READ FIRST)
- **`.adev/QUALITY.md`** - Quality standards (50/50 ritual)
- **`ADEV-LOCAL.md`** - Repo-specific extensions
- **`.adev-config.yaml`** - Configuration and rules
- **`CONTRIBUTING.md`** - Contribution guide (if exists)

---

**Remember**: Load A-Dev framework FIRST, apply constraints ALWAYS, document learnings CONTINUOUSLY.
