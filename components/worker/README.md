# Worker

## Boundary

Owns ephemeral worktrees, prompt construction, agentic and reprompting cycles,
resource containment, local validation, commits, branches and pull requests.
It cannot admit issues, approve its own output, bypass repository protections or
deploy to production.

Workers are designed to become horizontally scalable. All durable state and
leases remain outside the container; only disposable workspaces are local.

## GitHub permissions

Contents write, pull requests write, checks read and issues read. No Actions,
deployments or administration write permissions.
