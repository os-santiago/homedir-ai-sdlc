# Publication contract

Worker-created implementation PRs now include Closes #N and exactly one initial risk label. Worker-owned implementation and remediation commits carry Signed-off-by. The implementation prompt delegates committing to the worker.

Initial risk is inferred from changed paths: sensitive authentication/credential/payment paths are critical, platform/container/workflow paths are high, documentation-only changes are low, other changes are medium. This is triage assistance: reviewers must confirm or raise risk based on content, including sensitive changes outside recognized paths. Empty changes or failed risk inspection cannot publish a PR. Existing PR labels are preserved.

The worker does not assert acceptance, tests or translation completeness from the presence of a diff. Required repository checks and human approvals still apply. Existing SCC branch naming remains unchanged because it is part of the tracking protocol.

Policy lookup output must contain one JSON object with a nonempty policy identifier and decision. Null, malformed or multiple results are ignored rather than inserted into model context as an authoritative decision.

Validation: python3 -m unittest discover -s tests -p 'test_worker*.py' -v
