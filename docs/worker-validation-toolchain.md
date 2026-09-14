# Homedir worker validation toolchain

The worker invokes Maven after Java or Qute template changes. Its image must therefore include Java 21 and Maven rather than failing with `mvn: command not found` after model execution. The image workflow executes both commands using the immutable worker image tag before allowing deployment.

## Registry outage recovery

On 2026-09-14, Quay rejected the images for merged worker revision `02487c38b949e1dde484658aa2276989ff22e721` because the registry was read-only. The approved source was cloned at that exact revision on the VPS and built locally with a 2 GiB build memory limit and one CPU quota. The CLI revision remains pinned to `d78def29e8f84502f63218ac8ce078c8a4a3f965`.

A recovery image can add the same Java 21/Maven packages to that approved worker image. Record both the approved base revision and tooling change in image labels. Before activating it, run `java -version`, `mvn -version`, check the CLI revision, and inspect only non-secret profile fields. Never print the environment file.

Only replace the worker while no implementation is active. Preserve the stopped previous container for rollback, reuse its state/worktree/log mounts and the existing protected environment file, and verify startup before requeueing an issue. If startup validation fails, stop the candidate and restart the preserved container. Keep Homedir and other services running.

This manual recovery does not repair registry availability. Once normal publishing works again, deploy the reviewed source through the SHA-tagged image workflow and verify the worker revision before removing retained recovery resources.
