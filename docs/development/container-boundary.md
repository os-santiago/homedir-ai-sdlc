# Container boundary qualification

This increment tracks #80 under #75. `container_boundary.py` defines a closed
Podman profile for reviewed local Python probes. It is deliberately not connected
to the worker, ledger or model route. It accepts only a preloaded immutable image
ID, one regular fixture file and a 1–60 second deadline. There is no arbitrary
runtime-option, network, credential or workspace-bind parameter.

## Enforced profile

| Boundary | Configuration |
| --- | --- |
| Identity | UID/GID 10000, all capabilities dropped, no-new-privileges |
| Network | None, no published ports, local runtime only |
| Namespaces | Private PID, IPC, UTS and cgroup namespaces |
| Filesystem | Read-only root; only one read-only reviewed fixture bind mount |
| Writable space | Private tmpfs: /workspace 32 MiB, /tmp 16 MiB, /home/runner 8 MiB; noexec/nosuid/nodev |
| Memory | 128 MiB RAM; memory+swap also 128 MiB |
| CPU/processes | 0.5 CPU; 16 PIDs |
| Files/descriptors | 8 MiB maximum file size; 64 file descriptors |
| Lifetime | Podman's runtime-owned timeout, independent of a Python process-group watchdog |
| Environment | Image defaults cleared; explicit PATH/HOME/LANG only |
| Logs | No persistent container log driver |

The tmpfs directories have sticky 1777 permissions so the non-root UID can write
inside its own isolated container. They are not host directories. The profile
does not mount a checkout, Git metadata, ledger, host home, SSH/GitHub/model
credentials, production data or engine socket. A fixture is trusted code reviewed
by the operator and must not contain secrets. Filename/path checks do not detect
credentials embedded in source. The image must also be reviewed and preloaded;
an immutable ID is an identity constraint, not a security attestation.

`runtime_environment()` supplies only local engine configuration variables; it
does not forward caller tokens, language hooks or a remote engine endpoint.
This does not make arbitrary host engine configuration trustworthy. The runner
host and Podman configuration remain an operator-controlled trust boundary.

## Real qualification

The integration suite is opt-in locally through `SDLC_BOUNDARY_TEST_IMAGE`; when
set, an unavailable runtime or non-v2 cgroup host is an error, not a skipped test.
CI installs Podman and runs the probes with a digest-pinned Python fixture image.
The suite checks actual cgroup values and attempts forbidden operations, including
memory exhaustion, excess children and a session-escaping child stopped by the
runtime timeout. Each probe inspects the stopped container and removes only its
unique `sdlc-boundary-*` instance. Unit tests alone do not qualify the boundary.

On 2026-09-15, local Fedora Remix had Podman 5.8.2 and cgroups v2. Rootless execution
failed at `newuidmap` with Operation not permitted. That mode is not qualified;
no host namespace configuration was changed. The local rootful engine successfully
ran the non-root container probes. This is not a claim of rootless isolation.
The image ID used was
`sha256:28eb0cb65acb65b970e85c0dc57d10067868fae8dd00d072413df273132123ac`,
resolved from the Python fixture image whose pinned reference is recorded in CI.
The VPS runtime has not been qualified by these local results.

Example on an already provisioned qualification host:

```bash
SDLC_BOUNDARY_TEST_IMAGE=sha256:<approved-local-image-id> \
  python3 -m unittest discover -s tests -p 'test_container_boundary_integration.py' -v
```

## Remaining production gates

This profile is intentionally too restrictive to perform an online model request
or fetch build dependencies. Do not enable network access or inject a provider key
to make a pilot pass. The next integration must supply a narrowly scoped model
gateway, approved/prebuilt validation dependencies, and trusted candidate input
selection. Any new mount/network permission requires corresponding denial probes.

Writes are ephemeral: the tmpfs workspace is not a durable checkpoint. Before
connecting to #75, implement a bounded artifact export/import protocol, preserve
partial work on timeout/cancellation, and reconcile container identity/lifecycle
with the existing ledger. No automatic application of container output to the
repository is implemented. Candidate tests need the same restrictions as generation.

The subsequent [offline receipt collector](container-receipts.md) preserves complete
emitted proposals and reconciles container identity with the ledger. Unsent tmpfs
changes, candidate application and production integration remain outside that step.

Shared-kernel containers do not establish protection from every kernel/runtime
vulnerability or qualify a public multi-tenant service. Evaluate stronger isolation
before accepting hostile tenants. For the current lane, #75 remains open and the
production worker retains its existing route. These probes prove specific controls,
not an autonomous requirement-to-production delivery.
