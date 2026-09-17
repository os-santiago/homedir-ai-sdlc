# Bounded untrusted container receipts

This is the offline #82 increment of #75. The collector joins the qualified
container profile to the durable ledger without adding a mount, network access
or credential. It still runs operator-reviewed synthetic fixtures, not real model
implementations. The production worker does not call this path.

## Wire contract

The fixture emits UTF-8 JSON objects separated by newlines and flushes complete
frames. Each frame proposes one file version or deletion:

```json
{"path":"allowed.txt","content":"cHJvcG9zYWw=","mode":420}
{"path":"obsolete.txt","delete":true}
```

The trusted caller supplies 1–16 exact allowed paths. Paths must be relative and
use simple ASCII components; traversal, metadata directories, backslashes and
extra fields are rejected. File contents use canonical base64 and modes are
0644 or 0755. A container cannot supply an outcome, run identity, validator result
or publication decision through this channel. Duplicate JSON keys are rejected.

Limits are 32 complete frames, 256 KiB decoded per file, 1 MiB decoded latest-file
total, 360 KiB per frame and 2 MiB total wire traffic. Repeated paths replace their
latest proposed content while earlier accepted receipts remain auditable. A
malformed/oversized frame terminates capture; the already persisted prefix stays
available. Raw rejected output and stderr are not stored or printed. This is a
proposal format, not a patch-applier or executable archive format.

## Durability and lifecycle

The collector reserves the edit budget and records the unique container name and
immutable image ID before launch. Each complete accepted frame is fsynced through
an immutable artifact and an atomic ledger manifest update before reading further
proposals. Receipts contain trusted run, requirement/base/policy/plan identity,
step, attempt and container identity. Their observation is host-owned and they
are always untrusted; no proposal is written into the source checkout.

The ledger upgrades to schema 3. Older readers reject it instead of ignoring an
unresolved container. Generic finish/recovery is blocked while container intent
exists. Checkpoint adoption preserves version 3 and all prior limits/evidence.
The latest accepted receipt survives collector SIGKILL; unflushed or incomplete
frames, unread pipe data and unsent tmpfs files do not. A source snapshot before
launch is still recorded by the existing ledger, but it is not a copy of the
container's ephemeral workspace.

On completion, cancellation, malformed output or host deadline, close the output
pipe before removing the container to avoid backpressure blocking cleanup.
Reconciliation verifies the exact name and qualification label, force-removes only
that container and confirms absence. Engine errors preserve unresolved intent;
they cannot free the reservation. A later trusted caller uses
`recover_container_capture(run)` to reconcile and preserve the latest receipt.
The runtime's own timeout remains active if the collector dies.

An exit-zero observation is `exited`, not `validated`. Nonzero runtime exits are
`failed`; the collector does not infer OOM versus runtime timeout from an exit code.
Its own deadline records `timeout`, malformed frames `invalid`, explicit
cancellation `cancelled`, and crash reconciliation `interrupted`. Every completed
capture conservatively retains its full reservation charge and leaves status
`untrusted`. Existing validated checkpoints are preserved, never overwritten by
container declarations. There is no automatic publication eligibility.

The ledger keeps content-addressed receipt history: at most 32 progress snapshots
plus one final snapshot per capture, each capped at 2 MiB. Retention and total disk
quotas across runs remain a deployment requirement; do not run this indefinitely
without a lifecycle/storage policy. Receipt files are private, may contain proposed
source data, and must not be posted as raw logs.

## Validation and remaining gates

Unit tests cover framing, limits, scope, corruption, prior checkpoints, unresolved
runtime state and refusing removal of an unrelated container. Opt-in real Podman
tests cover success, timeout, malformed output, output flooding, cancellation and
SIGKILL with durable prefix recovery. CI runs both suites against the same pinned
image/profile used by the containment probes.

Before a real issue can use this lane, add approved input/context export, safe
application to a fresh candidate with complete acceptance validation, a scoped
model gateway, prebuilt validation dependencies, and orchestration/retention gates.
Any model-generated patch remains untrusted even if its JSON is valid. #75 stays
open; these fixtures do not establish autonomous delivery to production.
