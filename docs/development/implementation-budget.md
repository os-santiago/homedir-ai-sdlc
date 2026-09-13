# Initial implementation budget

Initial implementation runs the CLI directly in the worker-owned checkout, using
the existing complexity budget (15, 20 or 25 minutes). There is no HTTP generation
or fallback route. Remediation retains its existing limit; this does not establish
a lifetime budget across retries. Scoped validation runs after agent execution.

The worker requires a clean PR branch and records its starting SHA. The agent
receives that SHA, the required branch and instructions to read applicable
repository guidance. It must leave real changes in this checkout. Branch switches,
rewritten base history and prose-only/no-diff results are rejected. Committed and
uncommitted changes both undergo scoped validation before the existing PR flow.
Logs record the base SHA, branch, changed paths and validation outcome. Absence of
a scoped validator is explicitly recorded; CI and required reviews remain gates.

The HTTP implementation service remains independently available with its existing
cancellation support, but the worker does not call it until a repository mutation
contract exists. No container mounts or production services are changed by this
routing change. CLI timeout is preserved as exit 124. This does not provide
resumable checkpoints or exactly-once execution.

Validation: `python3 -m unittest discover -s tests -p 'test_worker*.py' -v`.
