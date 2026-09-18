# Seccomp profile provenance

`seccomp.json` is adapted from `/usr/share/containers/seccomp.json` in Fedora
`containers-common-0.67.0-1.fc42.noarch`, derived from the containers/common
project, licensed under Apache-2.0 (see the repository's LICENSE).

- Upstream: https://github.com/containers/common
- Original file SHA-256: `2598b3b98e6970f37f917e210202fa8976aefcd99abf8955803a6e35bba17eb4`
- Modification: replace the conditional chroot allow/deny rules with one
  unconditional `SCMP_ACT_ALLOW` chroot rule. JSON whitespace is normalized.
- Purpose: let Chromium chroot inside its own user namespace with its sandbox
  enabled. The outer container retains zero capabilities and no-new-privileges.
  Seccomp permits the syscall; the kernel still enforces namespace capabilities.

No other syscall permissions were changed. The runtime loads this operator-owned
profile from the repository, never from candidate HTML/CSS or a model proposal.
The image remains networkless and read-only with private namespaces and bounded
resources. The integration suite verifies the outer process cannot chroot and
the sandboxed browser can evaluate the layout. CI must qualify profile changes.
