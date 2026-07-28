# Admission Controller

## Boundary

Owns issue normalization, schema validation, admission policy evaluation,
duplicate/conflict detection, risk classification and the immutable admission
decision. It never creates branches, invokes implementation agents, merges PRs
or observes production.

## Contract

- Consumes `IssueAdmissionRequested.v1`.
- Produces `IssueAdmissionDecided.v1`.
- Persists the decision, policy version and evidence before publishing.
- Reprocessing the same repository, issue revision and policy version must
  return the same decision.

## GitHub permissions

Issues read/write and metadata read. No contents, Actions or administration
write permissions.
