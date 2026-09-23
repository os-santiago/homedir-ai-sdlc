# Approved edit targets in the shadow lane

`generate_proposal(..., targets=...)` delegates replacement text, while trusted
policy owns the file, original text, occurrence count and intent of each target.
It validates all anchors against the immutable base before charging an attempt.
The provider must return every target exactly once using only `id` and `text`.
Original offsets are replaced in descending order: generated text cannot become
another target. Invalid, duplicate, missing, overlapping, stale, oversized and
no-op proposals fail closed. The caller's plan is copied before provider execution.

The receipt records the full plan, its canonical SHA-256, input hashes, provider
evidence and request hash. Existing deadlines and full attempt reservations apply.
A syntactically valid response remains untrusted; it creates no checkpoint and
does not publish, merge or deploy anything. Replacement text can still contain
unsafe or incorrect code; approved locations do not establish semantic safety.

`reputation_edit_plan.py` is explicitly a reviewed plan for Homedir #1564, not a
general issue planner. Its nine targets cover desktop/mobile tracks, the inner
member grid, names, handles and all ten linked/fallback template branches. Version
`reputation-approved-targets-v2` specifies concrete CSS declarations after the
first live trial showed that high-level intent was insufficient. A changed source
anchor requires plan review instead of fuzzy matching.

## September 23 qualification

Base: `os-santiago/homedir@e8ca4b42ea358a693aea9e8b8212f4dafe712888`.
Requirement SHA-256:
`73709318fc55c02a623724c304b8429143a0bacc49ac728c63e67864913dfde3`.
The restricted Qute 3.26.4/browser validator image was
`sha256:691d16cc13cd918730e2868f5346fcd6ba32563876de4a1373ee297a719b705e`.

Each live run had two attempts, a 250-second edit budget and a 120-second request
deadline plus five seconds reserved for cleanup. No exhausted run was reset.

| Plan/profile | Attempt | Provider elapsed | Result |
| --- | --- | --- | --- |
| v1 / lightning-json-v1 | 1 | 25.901 s | Valid replacement JSON; browser rejected layout |
| v1 / lightning-json-v1 | 2 | 110.270 s | Valid replacement JSON; browser rejected layout |
| v2 / lightning-reasoned-json-v1 | 1 | 120.070 s | Timeout/transport failure; no proposal |
| v2 / lightning-reasoned-json-v1 | 2 | 120.091 s | Timeout/transport failure; no proposal |

Both v1 candidates preserved accessible full names but failed ellipsis, collision
and horizontal overflow checks at 1024 and 375 pixels. The second attempt received
validator feedback. Request payload hashes were
`3e986619bf8cebdc960c024d7aab72072c8e3a016495e559a8b1ab864ad884f7`
and `d8c693f3cb3ec8b4140ced49cb26839d5e1ffc4613692f14badef726818496d2`.
Both v2 requests used payload hash
`e524b7d072f45e307839de101009fa11ad8b6ade749e2e37784259b7857b139c`.
Plan precision and inference profile changed together; this is not a controlled
comparison of either variable. Neither profile is qualified for autonomous delivery.

An independently authored **supervised reference implementation** of v2 passed
the same candidate-to-Qute/browser checks at both widths, including short-name
stability and all five row templates with linked/fallback variants. Its receipt
explicitly identifies `supervised-reference-fixture`, with no fabricated provider
metadata. This establishes that the plan can solve the component bug; it is not
evidence that the remote model produced a correct implementation. Its checkpoint
also remains null. Application tests and maintainer review are separate gates.

Local operator evidence roots (ephemeral WSL storage) are
`/tmp/homedir-targeted-1564-bc915q1p`,
`/tmp/homedir-targeted-v2-1564-8iqz6g0w` and
`/tmp/homedir-reference-1564-y159339s`. The first live v1 runner recorded the plan
hash and an external target-plan.json; the final implementation records the full
plan inside the receipt, as verified by regression tests.

## Repeatable checks and remaining work

Run `python3 -m unittest discover -s tests -p 'test_worker*.py' -q` for protocol,
scope, mutation, atomicity, budget and receipt tests. Build the reviewed validator
and set `SDLC_BROWSER_TEST_IMAGE` to its immutable image ID when running
`test_reputation_layout_integration.py`. The positive connected test uses a
deterministic provider fixture, not a network model.

Production still uses its existing worker route. This increment does not connect
the shadow lane to production admission or budget full-application validation.
Before activation, qualify a provider on representative tasks, integrate durable
validation and publication, and demonstrate reviewed delivery through deployment.
Parent #75 remains open. The practical outcome of this pilot is a reviewable
supervised product fix plus a more reliable proposal protocol, not completed
end-to-end autonomy.

The supervised product fix is submitted separately as
[Homedir #1571](https://github.com/os-santiago/homedir/pull/1571). Its eight
`ReputationHubResourceTest` tests passed in a complete Java 21 application startup,
including escaped full-name titles and fallback rendering. This is a separate
application validation gate, not promotion of the shadow run's checkpoint.

## Operational verification

The September 23 post-merge check confirmed worker/dashboard/implementation images
at merged #95 (`d30edf42f0578f9b63baa624b4e5930af5371266`). It also found the public
dashboard returning 502 while its local `/sdlc/dashboard` and `/q/health/live`
returned 200. Nginx referenced an obsolete container IP (`10.88.3.19:8080`) and
an obsolete health port (8090). The operator changed both upstreams to the existing
stable host mapping `127.0.0.1:8083`, tested Nginx configuration, and reloaded it.
Backup: `/var/backups/homedir-ai-sdlc-nginx-20260923T151230Z.conf` on the VPS.
Public dashboard and health then returned 200; Homedir also returned 200.
This was an operational proxy repair, not activation of the shadow worker lane.
