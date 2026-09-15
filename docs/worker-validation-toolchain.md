# Homedir worker validation toolchain

The worker invokes Maven after Java or Qute template changes. Its image must therefore include Java 21 and Maven rather than failing with `mvn: command not found` after model execution. The image workflow executes both commands using the immutable worker image tag before allowing deployment.

## Registry outage recovery

On 2026-09-14, Quay rejected the images for merged worker revision `02487c38b949e1dde484658aa2276989ff22e721` because the registry was read-only. The approved source was cloned at that exact revision on the VPS and built locally with a 2 GiB build memory limit and one CPU quota. The CLI revision remains pinned to `d78def29e8f84502f63218ac8ce078c8a4a3f965`.

A recovery image can add the same Java 21/Maven packages to that approved worker image. Record both the approved base revision and tooling change in image labels. Before activating it, run `java -version`, `mvn -version`, check the CLI revision, and inspect only non-secret profile fields. Never print the environment file.

Only replace the worker while no implementation is active. Preserve the stopped previous container for rollback, reuse its state/worktree/log mounts and the existing protected environment file, and verify startup before requeueing an issue. If startup validation fails, stop the candidate and restart the preserved container. Keep Homedir and other services running.

This manual recovery does not repair registry availability. Once normal publishing works again, deploy the reviewed source through the SHA-tagged image workflow and verify the worker revision before removing retained recovery resources.

## Recorded activation

The recovery image `localhost/homedir-ai:worker-02487c38-validation` was activated on 2026-09-14 at approximately 23:35 UTC. Its image ID is `ad1d94eba150137a56a08db1b6fa389ef39c8e14621c434c8e848ca70102ed29`. Java reported 21.0.12, Maven reported 3.8.7, and the CLI reported the pinned revision. The previous worker is retained as `ai-sdlc-worker-before-02487c38`. Homedir returned HTTP 200 after activation.

The first recovered #1564 attempt reached generation at 23:37:38 UTC and failed at 23:37:48 UTC when the provider returned HTTP 503: `ResourceExhausted: Worker local total request limit reached (150/32)`. No patch was generated. The worker exited the attempt normally and returned to its polling loop. A subsequent attempt was queued for the next normal cycle, allowing a cooldown rather than starting a concurrent implementation. Provider capacity remains separate from the successful image/toolchain checks.

The second Poolside attempt also returned capacity HTTP 503. An isolated CLI file-edit canary succeeded with `nvidia/nemotron-3.5-lightning-30b-a3b` in 67 seconds. The worker's runtime profile was temporarily switched to that model, with streaming disabled, temperature 0.2 and maxTokens 2048; the source default remains Poolside. The previous runtime configuration is retained at `/root/.sc-agent/config.before-lightning.json` and must not be printed because configuration backups may contain credentials.

The Lightning pilot ran from 2026-09-14 23:49:41 UTC to 2026-09-15 00:14:41 UTC and exhausted its 1500-second budget. It added five display-name title attributes but did not complete the CSS changes or validation. No PR was produced. The partial diff is preserved at `/var/lib/homedir-sdlc/run-summaries/issue-1564-lightning-20260915.patch`; preserve it before any checkout reset or retry. Issue #1564 remains failed rather than queued. The isolated canary is not evidence of end-to-end success.

Investigation identified a separate CLI defect: request cancellation stopped after response headers, leaving body reads outside the timeout. The proposed repair is tracked in `os-santiago/sc-agent-cli#397`, with stalled-body and cancellation regression tests. Request-level traces were unavailable for this pilot, so that defect is not established as the sole cause of its timeout. Review and validate the client repair before another full pilot.
