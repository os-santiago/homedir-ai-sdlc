# Release Manager

## Boundary

Owns quality and security gate reconciliation, review state, remediation
requests, normal auto-merge eligibility, deployment observation, production
verification and release metrics. It never edits implementation code and never
uses an administrative bypass.

## Success metrics

- Change failure rate.
- Lead time from accepted issue to verified production.
- Gate pass rate and remediation attempts.
- Deployment verification latency.
- Human escalation and rollback rate.

## GitHub permissions

Actions, checks, deployments and contents read; pull requests and issues
read/write. No administration or ruleset write permissions.

## Internal API

`POST /v1/releases/evaluate` evaluates required checks, actionable reviews,
issue coverage, validation evidence, remediation limits and post-merge release
status without bypassing repository governance.
