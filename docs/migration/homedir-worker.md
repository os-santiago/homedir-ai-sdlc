# HomeDir worker migration

This migration uses a strangler pattern. HomeDir labels remain a human-visible
compatibility projection while behavior and durable state move component by
component into this control plane.

## Migrated in the first functional slice

| HomeDir worker responsibility | New owner | Implementation |
| --- | --- | --- |
| `issue_acceptance_review` destructive and guardrail patterns | Admission Controller | `internal/admission.Evaluate` |
| Atomicity and complexity admission | Admission Controller | Acceptance-criteria limits and decomposition decision |
| Sequential issue processing | Orchestrator | Validated DAG and bounded ready-work selection |
| SCC no-op, timeout, validation and retry handling | Worker | `internal/cycle.Evaluate` |
| Check conclusion classification | Release Manager | `internal/gates.Evaluate` |
| Review, issue coverage and remediation limits | Release Manager | Unified gate snapshot evaluation |
| Post-merge release success/failure | Release Manager | Production verification state |

## Compatibility labels

`internal/platform/compatibility.Labels` preserves the current HomeDir label
vocabulary. Labels are projections only; they will be written by a GitHub
adapter after the event store and outbox land.

## Remaining extraction

1. GitHub App webhook verification and event normalization.
2. PostgreSQL workflow store, leases, audit log and transactional outbox.
3. NATS command/event adapter with at-least-once delivery.
4. GitHub projection adapter for labels, comments, branches and PRs.
5. Sandboxed agent runner and SCC compatibility adapter.
6. PR coverage evidence parser and remediation prompt builder.
7. Deployment provider adapter and production health verification.
8. Backfill importer for existing HomeDir JSON state.

Until these land, the current HomeDir worker remains the execution authority.
No production cutover should occur from health-only component containers.
