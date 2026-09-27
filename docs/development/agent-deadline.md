# Agent execution deadline

`HOMEDIR_SDLC_SCC_TIMEOUT_SECONDS` is the canonical positive integer cap in
seconds. The legacy `SCC_TIMEOUT_SECONDS` setting remains a fallback; the
canonical setting takes precedence. Production deployment sets 600 seconds.

The initial implementation uses the smaller of the configured cap and its
complexity budget. Capability discovery (`scc chat --help`) shares that deadline
with generation and scoped validation. Discovery is limited to ten seconds (or
the remaining budget, when smaller). A discovery timeout stops the attempt;
an ordinary unsupported-help exit permits the legacy CLI invocation. Remediation
also bounds discovery and generation together. Missing GNU `timeout` or invalid
budgets prevent execution instead of starting an unbounded agent.

GNU timeout allows a short process termination grace period: one second for
discovery, ten seconds for generation. These are cleanup allowances, not renewed
generation budgets.

This is an execution-boundary fix, not durable retry or end-to-end qualification.
The separately configured global validation command remains outside this agent
deadline. Human approval, CI and deployment gates remain required. No live model
implementation is claimed by the offline regression suite.

Validation:

```sh
bash -n platform/scripts/homedir-sdlc-worker.sh
python3 -m unittest discover -s tests -p 'test_worker_budget.py' -v
```
