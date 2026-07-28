# ADR 0001: Four independently packaged bounded components

- Status: Accepted
- Date: 2026-07-27

## Context

The original HomeDir worker combines admission, planning, implementation and
release reconciliation. This simplifies deployment but couples permissions,
state transitions, scaling and failure recovery.

## Decision

Use four bounded components: Admission Controller, Orchestrator, Worker and
Release Manager. Package each as an independent OCI image and coordinate them
through versioned contracts. Initially co-locate them in a pod, preserving the
option to split deployments without changing behavior.

## Consequences

- Permission and failure boundaries become explicit.
- Workers can scale independently after topology separation.
- Contract compatibility and distributed-workflow observability become
  mandatory.
- Cross-component changes require additive contract evolution.
