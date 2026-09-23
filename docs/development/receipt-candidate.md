# Recorded proposals to isolated candidates

`platform/scripts/receipt_candidate.py` connects the durable container receipts
to a fresh Git candidate for inspection. It is an offline first-step API, not a
production worker route or an acceptance validator.

With the existing `RunState` writer lock held, trusted orchestration calls:

```python
report = materialize_receipt(run, private_scratch_root, approved_exact_paths)
```

The scope must come from reviewed policy. The API rechecks the saved receipt's
checksum, run identity and file protocol, requires a reconciled container, then
clones the recorded base without hard links or checkout credentials. It removes
the candidate's source remote and applies only regular-file proposals. Symlink
and submodule ancestors, directory replacement, absent-file deletion, empty
proposals and no-op changes fail closed. Source dirty edits are not inputs.

Each successful application writes a sibling `.evidence.json` containing the
receipt hash, exact candidate snapshot hash, immutable run identity, approved
paths and original execution observation. `acceptance` is always `not-run`.
Application preserves the ledger, its budgets and previous checkpoint. It
cannot authorize publication. Timeout/failure proposals can be inspected, but
their original outcome remains visible.

The scratch root must be private and separate from source/state. No candidate
code is executed, so no candidate processes may be started concurrently during
application. Failed candidates remain for diagnosis; callers own bounded
retention. The API is Linux-only like the ledger. It starts at the recorded base
and does not compose prior steps or adopt the candidate into the run.

Before an actual Homedir delivery, the orchestrator still needs independent,
versioned acceptance validators in the restricted runtime, candidate adoption
bound to that evidence, controlled model access and the existing PR/release
gates. For Homedir #1564, CSS/Qute application alone cannot demonstrate desktop
and mobile overflow behavior. This increment claims no autonomous resolution.

Validation:

```sh
python3 -m unittest discover -s tests -p 'test_worker_receipt_candidate.py' -v
```
