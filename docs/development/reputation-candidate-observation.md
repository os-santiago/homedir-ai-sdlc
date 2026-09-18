# Exact-candidate Reputation Hub observations

`probe_candidate(run, materialization_report, image_id)` connects recorded file
proposals to a browser observation for the historical Homedir #1564 pilot.
The caller holds the run lock and supplies the operator-reviewed validator image.

The adapter verifies the materialization identity, receipt checksum, changed paths,
file bytes/modes and complete candidate snapshot before running. It reads only the
two pilot files, rejects deletion, symlinks, changed candidates and other scopes,
and requires the base's Quarkus version to match the renderer (3.26.4). It extracts
the five original row source fragments without evaluating or rewriting Qute.

Inside the existing restricted browser container, Qute 3.26.4 renders those
fragments with fixed linked/unlinked member, avatar/fallback and score/growth
scenarios. The engine is strict and has no reflection resolver. The only extra
string operation is the existing `substring(0,1)` initials expression; unsupported
expressions fail. The fixture supplies only the two score message resolvers.
The resulting rows and candidate CSS are measured by the sandboxed browser at
1024px and 375px. Both page scripts and external requests remain disabled.

Afterward the adapter rechecks the snapshot and writes a content-addressed
`observation-<hash>.json` in the private run directory. Evidence includes the
requirement/base identity, receipt/snapshot/template/CSS hashes, renderer version,
validator image and browser input hash. A mutation during observation discards
the result. An observation never creates a validated checkpoint or publication
intent, and it does not change existing ledger state.

This is an offline shadow probe with the existing 30-second container deadline,
not a production scheduler step. Lifetime validation-budget accounting and crash
reconciliation must be wired before using it in the autonomous worker. The
original whole-issue worker remains the only production lane.

## Coverage limits

This uses actual candidate row templates and the real Qute engine, with a fixed
component wrapper and fixture data. It does not compile the full Quarkus app,
render the full page/layout/includes, execute page JavaScript, test every data or
locale variant, or establish a served revision. Its result remains
`acceptance=component-only`, even when every component assertion passes. Passing
this probe cannot resolve #1564 or authorize a PR by itself.

The image installs Java and dependencies at build time. Runtime receives only
bounded row/CSS input through stdin, with no checkout mounts, credentials or
network. Java has a 96 MiB heap and a 10-second subprocess limit, within the
container's existing resource and lifetime limits. The CI browser job now checks
the proposal → candidate → Qute → browser path and rejects missing fallback
tooltips, invalid expressions and reflection access.

## Historical patch replay, 2026-09-18

The preserved Lightning patch from 2026-09-15 was reapplied to its original Homedir
base `e8ca4b42ea358a693aea9e8b8212f4dafe712888` in a separate Linux checkout.
It adds five link title attributes and does not change CSS. This was an offline
import/replay using fake-executor receipt metadata, not a fresh model execution,
and its requirement hash identifies the historical replay rather than a newly
admitted issue revision.

- Candidate snapshot: `51856bdb6981f3f273d67bbd9d5bf2f81b5c89a546ae80bd51c9b7cf5389527b`.
- Validator image: `sha256:691d16cc13cd918730e2868f5346fcd6ba32563876de4a1373ee297a719b705e`.
- Renderer: `qute-3.26.4-pilot-rows-v1`; five source rows, four data variants each.
- At both 1024px and 375px the component fixture failed `ellipsis`,
  `full-name-accessible`, `no-collision` and `no-horizontal-overflow`.
- The run remained `untrusted`, with no validated checkpoint or publication.

This is evidence that the preserved proposal does not satisfy the component
gate. It is not evidence about the current production page's full layout, and
it does not resolve issue #1564. The positive CI control independently proves
the same pipeline accepts a valid fixture without upgrading it to full acceptance.
