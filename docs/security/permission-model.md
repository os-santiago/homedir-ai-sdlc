# Permission model

Use one GitHub App installation identity per responsibility. Never share a
personal access token across containers.

| Permission | Admission | Orchestrator | Worker | Release Manager |
| --- | --- | --- | --- | --- |
| Metadata | Read | Read | Read | Read |
| Issues | Read/write | Read/write | Read | Read/write |
| Contents | None | Read | Read/write | Read |
| Pull requests | None | Read | Read/write | Read/write |
| Checks | None | Read | Read | Read |
| Actions | None | Read | Read | Read |
| Deployments | None | None | None | Read |
| Administration | None | None | None | None |

Installation tokens should be minted shortly before use and held in memory.
Database credentials and App private keys are injected through an external
secret store. Logs, events and prompts must redact credentials and sensitive
repository content.
