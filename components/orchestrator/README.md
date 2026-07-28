# Orchestrator

## Boundary

Owns decomposition, dependency graphs, ordering, concurrency limits and saga
coordination across related issues. It schedules atomic work; it does not run
coding agents or decide whether release gates passed.

## Invariants

- A work item has one owning plan and immutable acceptance criteria.
- Dependencies form a directed acyclic graph before execution.
- Dispatch uses leases and idempotency keys.
- Partial failure is handled through explicit compensation, not an implied
  distributed transaction.

## GitHub permissions

Issues read/write and metadata read. Contents and Actions are read-only.
