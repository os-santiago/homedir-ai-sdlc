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

The current WSL Podman profile does not allow Chromium user namespaces. The
validator therefore disables Chromium's internal user-namespace sandbox and
relies on the outer non-root, capability-dropped, read-only, networkless
container as its process boundary. This qualification limitation is explicit;
production use requires a reviewed runtime profile that either enables the
browser sandbox or provides equivalent isolation. The validator must not be
promoted on the basis of the component report alone.

The real browser integration tests are opt-in via
`SDLC_BROWSER_TEST_IMAGE=sha256:<immutable-image-id>`. The Python boundary and
report tests run without a browser image and fail closed on bad tags, oversized
input, timeout, malformed report or cleanup failure.
