# HomeDir AI SDLC

[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![CI](https://github.com/os-santiago/homedir-ai-sdlc/actions/workflows/ci.yml/badge.svg)](https://github.com/os-santiago/homedir-ai-sdlc/actions/workflows/ci.yml)

An autonomous, policy-driven software delivery control plane for HomeDir and
other repositories. The platform turns acceptable issues into ordered,
auditable implementation work and follows every change through protected
quality, security, and production gates.

## Deployable components

| Component | Owns | Must not own |
| --- | --- | --- |
| Admission Controller | Issue normalization, policy evaluation, risk classification, admission decisions | Branches, implementation, merge or deployment |
| Orchestrator | Work graphs, decomposition, ordering, concurrency, saga coordination | Code generation or release gate decisions |
| Worker | Isolated worktrees, agentic cycles, reprompting, validation, branch and PR production | Admission policy or production authority |
| Release Manager | Checks, reviews, remediation requests, merge eligibility, deployment verification and release metrics | Direct code implementation or policy bypass |

Each component is built as a separate OCI image. The first deployment topology
places the four containers in one Podman/Kubernetes pod for a small operational
footprint, while preserving boundaries that allow workers and controllers to be
split into independent deployments later.

## Repository layout

```text
components/                 deployable source, Containerfile and runbook per component
contracts/                  versioned commands, events and JSON schemas
internal/platform/          narrow shared runtime libraries
policies/                   versioned default policy bundles
deploy/gitops/              declarative base and environment overlays
platform/observability/     dashboards, alerts and telemetry configuration
docs/architecture/          architecture decisions and component boundaries
```

See [Architecture](docs/architecture/README.md) and
[GitOps operations](deploy/gitops/README.md) before adding functionality.

## Local validation

Prerequisites: Go 1.24+, Podman or Docker, and Kustomize.

```bash
make test
make build
make render
make containers
```

Run a component:

```bash
go run ./components/admission-controller/cmd
curl http://localhost:8080/healthz
```

## Design rules

1. Git is the source of truth for code, policy and deployment desired state.
2. GitHub is an external system to reconcile, not the platform database.
3. Durable workflow state belongs in PostgreSQL; coordination uses versioned
   commands and events.
4. Labels and comments are human-readable projections, not transaction state.
5. Every handler is idempotent and every state transition is auditable.
6. Components use separate identities and least-privilege GitHub permissions.
7. No component can bypass branch protection, required reviews, checks,
   rulesets, secrets controls, or deployment gates.

## License

Apache License 2.0, matching HomeDir.
