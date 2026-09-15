# Offline durable run ledger

This is the first implementation slice of #75 and ADR 0003, tracked in #76.
`platform/scripts/durable_run_state.py` is a Linux/POSIX standard-library module
for trusted orchestration code. No production worker imports it; no feature flag
or executor is activated by this change. It makes no model, GitHub or deployment
calls. Existing production execution and reconciliation remain unchanged.

## Contract

Use one private (0700) state root per repository, outside its candidate checkout.
Every writer must use that same root. Hold `RunState` as a context manager for the
entire attempt; the root lock permits one writer, including across run IDs. The
manifest contains schema version, run/repository identity, requirement hash, base
SHA, policy/plan versions, phase reservations, attempts, wait state, outcomes,
artifact checksums, a validated checkpoint reference and publication intent.
JSON is written through a private temporary file, fsynced, atomically replaced,
and its parent directory fsynced. A checksum detects accidental corruption; it
does not authenticate a malicious writer. State must be on a local filesystem
with reliable POSIX locking and rename/fsync semantics, not an unqualified NFS
mount. The caller must not allow executor access to the state root.

`begin(phase, seconds, step_id)` captures the input and durably charges the entire
reservation before execution. Edit and validation have independent persistent
balances. `finish(outcome, elapsed)` captures the result and refunds only unused
time reported by the trusted supervisor. The supervisor must enforce wall-clock
limits and kill its process group; this ledger does not supervise processes.
`recover_interrupted()` captures remaining work but never refunds an uncertain
reservation. Stop and verify all prior child processes before recovery or capture.
An active reservation cannot be replaced with a new attempt. Attempt limits
survive reopen, even when failures consume little execution time.

Snapshots contain a binary Git diff against the recorded HEAD plus base64 contents
and modes for regular, non-ignored untracked files. They are private untrusted
artifacts, including after an executor reports success. Ignored files are excluded;
index staging distinctions and empty directories are not preserved. Symlinks in
untracked paths, unsupported file types, changed HEAD and captures over 16 MiB
fail without resetting or deleting the source checkout. Git output is spooled to
a temporary file; the caller still needs disk quotas and process/resource limits.
Artifacts may contain source data: never attach them to public logs automatically.

Only a successful trusted validation of an unchanged snapshot establishes a
checkpoint. A validator that mutates files cannot attest to the resulting patch.
`checkpoint()` returns integrity-checked prior validated content for the matching
identity/base; it never restores or applies it. Later integration must restore it
to a fresh isolated checkout and revalidate any partial/stale work. A changed
requirement, policy, plan or configured limit cannot silently reuse the same run.

`wait(seconds)` supports at most two delays of up to 180 seconds, separate from
active compute. `release_wait()` requires the persisted deadline to have elapsed
and refuses a wait older than 24 hours. The supervisor owns provider classification
and escalation; clocks must be trustworthy. These are conservative initial limits,
not a scheduler or a reliability claim.

## Publication ambiguity

After validation, `publication_intent(branch)` records a stable identity key and
candidate hash before a trusted publisher acts. The caller should carry the key
into the external PR/branch identity. If the acknowledgement is lost, a repeated
intent is blocked. The supervisor must query external state and use
`reconcile_publication(key, branch, pr_number)` only after verifying the exact
repository, branch, run identity and candidate head. That external verification is
not implemented here. Conflicting PR acknowledgements fail; identical ones are
safe to replay. If no PR is found after an uncertain call, do not automatically
create again: pause for authoritative reconciliation. This sacrifices liveness
in an ambiguous crash window to avoid duplicate publication; it is not an
exactly-once GitHub delivery guarantee.

## Remaining before production integration

- Trusted runner with enforced deadlines, child termination and restricted executor
  credentials/filesystem/network, including isolation of candidate tests.
- Approved validator mapping and acceptance evidence for the exact candidate SHA.
- Fresh-worktree checkpoint restoration and stale-input invalidation workflow.
- Bounded plan scheduling and lifetime accounting across planning/remediation.
- External publication reconciliation adapter and disabled-by-default worker route.
- Shadow qualification and failure drills before enabling publication.

#75 remains open until those integration criteria are met. A successful ledger
test does not establish an autonomous requirement-to-production delivery.

## Validation

`python3 -m unittest discover -s tests -p 'test_worker_durable_state.py' -v`

Tests use real temporary Git repositories, an abrupt child-process exit, timeout
and cancellation outcomes, stale inputs, corrupt state, lock contention, budget
exhaustion, bounded waits and a fake publisher with a lost acknowledgement.
