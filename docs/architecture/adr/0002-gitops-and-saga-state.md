# ADR 0002: GitOps desired state and saga-based workflow state

- Status: Accepted
- Date: 2026-07-27

## Decision

Git stores deployment and policy desired state. PostgreSQL stores durable
workflow state and an outbox. GitHub is reconciled as an external system.
Multi-issue delivery uses dependency-aware sagas with compensating actions.

Runtime mutations to deployments are prohibited. Image promotion occurs by
updating immutable digests in an environment overlay and merging that change.

## Consequences

- Every production state is reproducible and attributable to a commit.
- Rollback is a Git revert or forward-fix of desired state.
- Secrets require an external secret controller and never enter Git.
- A failed multi-issue initiative is explicitly paused, compensated or
  escalated; it is never presented as atomically rolled back.
