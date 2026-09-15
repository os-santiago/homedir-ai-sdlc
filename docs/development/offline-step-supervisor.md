# Offline step supervisor and checkpoint restoration

This increment implements #78 under #75. It adds trusted-command supervision and
fresh-checkout restoration to the [durable ledger](durable-run-state.md). Nothing
imports this runner from the production worker, enables publication or invokes a
model. The command API is for operator-authored local fixtures, not shell text or
validator commands supplied by an issue or model.

## Execution contract

`execute_step(run, phase, seconds, step_id, argv, cancelled=predicate)` reserves
the phase budget before starting a separate Python watchdog. The watchdog inherits
the ledger lock, uses an absolute monotonic deadline and starts the fixture in a
new process session. It stops the entire process group on timeout/cancellation
and also after the direct parent returns, so background children cannot continue
writing during capture. Cleanup sends TERM, then KILL, reaps the direct child and
checks Linux `/proc` for remaining live group members. Failure to confirm cleanup
leaves the reservation unresolved; it does not create validated evidence.

The watchdog retains its deadline and lock if the invoking caller is killed. When
it exits, the next caller can acquire the lock and recover the interrupted
reservation with its full charge. Tests exercise this with SIGKILL, not just an
exception. A normal caller records a structured outcome, return code and elapsed
duration, then captures the repository through the ledger. Cleanup may exceed the
edit deadline by a bounded allowance; charged execution is capped at the original
reservation. The supervisor rejects an absent/failed watchdog result rather than
guessing success. Validation uses its own phase balance and an unchanged candidate.

Commands receive a minimal environment and a private temporary HOME. GitHub/model
tokens, Python hooks and user Git configuration are not inherited. Raw output is
discarded; command arguments are stored only in private temporary watchdog inputs,
which may remain after a hard crash. Never put credentials into fixture arguments.

This is **not an isolation boundary**. Trusted fixtures must not create a new
session to escape their process group, attack the watchdog or access host files.
Simultaneously killing the caller and watchdog is not a supported automatic
recovery drill. Production execution requires a restricted container/cgroup with
resource and network controls, credential separation and authoritative process
cleanup. Never apply this API directly to untrusted generated commands. If the
watchdog/host fails unexpectedly, reconcile processes before recovery. The ledger
lock is shared only by clients using the same state root.

## Checkpoint restoration

`restore_checkpoint(run, scratch_root)` accepts only a matching, integrity-checked
validated checkpoint from a quiescent run. It creates a new directory under a
private scratch root, clones the local repository without hardlinks or checkout,
checks out the recorded base and applies the binary patch. Git hooks and global
configuration are disabled for these operations. Non-ignored untracked files are
recreated with exclusive/no-follow opens; traversal, Git metadata paths, symlink
parent collisions and unsupported modes are rejected. The reconstructed snapshot
must exactly match the checkpoint before adoption.

The original checkout is never reset or removed. Failed restoration retains its
candidate for inspection. The module does not clean up old candidates automatically;
the later lifecycle manager must enforce storage quotas and safe retention.
Scratch and state roots must be separate from the candidate checkout. Git commands
have individual 30-second limits; restoration scheduling and its lifetime compute
accounting remain part of the orchestration integration.

The ledger stores an additive `candidate_repo` field while its original run,
requirement, base, policy and plan identity stays fixed. `adopt_checkpoint` preserves
attempts, waits and edit/validation balances. Reopening that same run follows the
adopted candidate; it does not create a new run with replenished limits. Partial
work after the last validated step remains in the previous checkout and is not
silently reapplied. A subsequent validator can run against the restored candidate.

## Remaining gates

#75 stays open. Next increments must supply the restricted executor and test
environment, trusted validator mapping, bounded multi-step scheduling, external
publication reconciliation and a disabled-by-default worker integration. Only
after those gates and shadow qualification can a real issue use this route.
No production completion or end-to-end autonomy is established by these fixtures.

Validation: `python3 -m unittest discover -s tests -p 'test_worker_durable_runner.py' -v`.
