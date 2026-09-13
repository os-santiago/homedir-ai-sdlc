# Initial implementation budget

Initial implementation uses one wall-clock budget selected by the existing issue
complexity policy (15, 20 or 25 minutes). The health probe, HTTP generation and
any direct CLI fallback consume that same budget. Remediation retains its own
existing limit; this change does not establish a lifetime budget across retries.

Direct CLI fallback is permitted only when the implementation service health
endpoint is unavailable before submission. A failed submitted request, including
an HTTP timeout, stops the attempt rather than potentially duplicating remote
work. HTTP client timeout is classified as exit 124. Operators should investigate
the existing attempt before retrying an ambiguous result.

PR #60 adds server-side cancellation. Until that change is deployed, client
timeout limits the worker's wait but cannot guarantee remote process cleanup.
Neither change provides resumable checkpoints or exactly-once execution.

Validation: `python3 -m unittest discover -s tests -p 'test_worker*.py' -v`.
