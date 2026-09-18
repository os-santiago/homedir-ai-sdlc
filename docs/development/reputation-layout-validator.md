# Reputation Hub layout validator

The validator is the first independent acceptance adapter for the Homedir #1564
pilot. It receives rendered HTML and CSS as data and measures the two required
viewports (1024px and 375px). It checks visible rows, full-name accessibility,
single-line ellipsis, score separation and stability, row height, and global
horizontal overflow. It never loads a URL, executes page scripts, accepts
arbitrary test commands, or receives a repository mount or credential.

`platform/scripts/reputation_layout_probe.py` launches the pinned validator
image through the existing qualification boundary shape and verifies the
structured report, input hash, exit status and owned-container cleanup. A
component result is labelled `acceptance=component-only`; it cannot create a
checkpoint or authorize a PR/release.

Chromium's internal sandbox is enabled. The reviewed seccomp profile permits
`chroot`, which Chromium uses inside its own user namespace. It does not grant
CAP_SYS_CHROOT or any other container capability; the outer UID 10000 process
still cannot chroot. All other syscall rules remain the Fedora containers-common
default. See the adjacent [profile provenance](../../platform/validators/reputation-hub/NOTICE.md).

The earlier diagnosis that WSL did not support Chromium user namespaces was
too broad. Two separate failures were reproduced: the default capability-gated
seccomp rule rejected Chromium's nested chroot, and `addStyleTag` waited for
page-side events while page JavaScript was disabled. Trusted synchronous DOM
style insertion resolves the second failure without enabling page scripts.

Local qualification uses rootful Podman with non-root container processes; it
does not qualify a rootless engine or the production VPS. Component evidence
still does not establish Qute compilation, a matching candidate revision, or
production acceptance. The validator cannot authorize publication.

Real browser integration tests are mandatory in the `browser-acceptance` CI job.
For local runs, set
`SDLC_BROWSER_TEST_IMAGE=sha256:<immutable-image-id>`. The Python boundary and
report tests run without a browser image and fail closed on bad tags, oversized
input, timeout, malformed report or cleanup failure.
