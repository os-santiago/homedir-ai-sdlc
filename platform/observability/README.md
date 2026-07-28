# Observability

Every component emits structured logs and will expose OpenTelemetry traces,
metrics and health endpoints. Telemetry must include correlation, causation,
plan and work-item identifiers; component, contract and policy versions;
state-transition outcome and latency; agent iterations and remediation
attempts; and release lead time, gate failures and escalation rates.

Dashboards and alerts belong here as code. They are projections and never the
control-plane database.
