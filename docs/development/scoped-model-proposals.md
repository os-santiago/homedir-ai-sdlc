# Bounded scoped model proposals (shadow only)

The trusted `generate_proposal` adapter reserves one edit attempt before calling
a provider. It verifies the requirement hash and original file contents against
the recorded immutable base. Policy supplies a small context and exact allowed
paths. The model returns at most 16 JSON text replacements, each with an exact
match count. All replacements apply in memory; malformed JSON, unexpected paths,
ambiguous matches, oversized output and no-op proposals are rejected. Accepted
bytes become untrusted file entries for the existing candidate materializer.

`bounded_provider.request_proposal` makes one non-streaming request to the fixed
NVIDIA HTTPS endpoint. It disables environment proxies and refuses redirects.
The operator-selected credential travels to a trusted helper over stdin and to
the endpoint in the authorization header, never in argv or model context. The
helper inherits only PATH/LANG. A POSIX alarm covers connection and response-body
reading; the parent kills and reaps it after the deadline plus two seconds.
Requests allow at most 120 seconds, 4,096 output tokens and 512 KiB response bytes.
Only complete `stop` responses can be applied. Capacity errors, truncated output
and timeouts remain failures, without automatic retries or provider switching.

The adapter reserves request seconds plus five seconds of transport allowance,
charges the full reservation, and records the request/input hashes, provider
outcome, model, elapsed duration, usage and bounded response. Provider exceptions
leave the reservation active for explicit recovery after process reconciliation.
An injected transport must enforce its own deadline and cleanup contract. The
data-only helper's independent alarm limits an orphaned request, but response
recovery after an orchestrator crash is not implemented.

Schema 4 adds `file-proposal` artifacts and a latest-proposal pointer. Existing
schema 1–3 runs remain readable; old readers reject upgraded manifests. After an
upgrade, subsequent container captures update the same pointer without downgrading
the schema. A failed newer attempt records empty entries and cannot accidentally
materialize an older success. Candidate materialization rechecks the receipt and
scope, uses a separate checkout and never creates a checkpoint or publishes.

This is a first-step shadow API, not a production worker route. A retry proposes
against the original base with trusted validation feedback; it does not silently
adopt a partially accepted candidate. Qute/browser observations remain component
evidence. Full application validation, validation lifetime accounting, durable
transport reconciliation, reviewed publication and production observation are
still required before this can replace the whole-issue production lane.

## Validation

`python3 -m unittest discover -s tests -p 'test_worker_scoped_proposal.py' -v`

Tests cover exact edits, malformed/ambiguous scope, incomplete responses,
interruption accounting, resume, mixed container/provider ordering, publication
denial, capacity sanitization, redirects, oversized bodies and a stalled body
interrupted by the independent deadline. The existing materialization and real
Qute/browser integration suites remain mandatory.

## Live shadow experiment, 2026-09-18

The fresh #1564 experiment used the original Homedir base
`e8ca4b42ea358a693aea9e8b8212f4dafe712888`, the current issue body, and 11,038 bytes
of JSON context: the actual CSS and five original Qute row excerpts. The existing
NVIDIA credential stayed on the VPS. A trusted SSH wrapper selected the model;
the model received neither SSH access nor tools. The production worker remained
on merged revision `55052df011934c34230d5954d20b911db3d39dd9` throughout admission.

The recorded run allowed two 125-second reservations (120-second requests plus
transport allowance), with no budget increase:

| Attempt | Model | Provider duration | Result |
| --- | --- | --- | --- |
| 1 | nvidia/nemotron-3.5-lightning-30b-a3b | 120.078 s | timeout-or-transport-failure; no complete response |
| 2 | poolside/laguna-xs-2.1 | 0.552 s | HTTP 503 capacity failure |

Both attempts were charged in full, leaving zero edit budget. There was no
applicable model proposal, candidate observation, checkpoint or publication.
Poolside was an explicit operator comparison using the remaining attempt, not
an automatic fallback. These results establish bounded failure handling, not
successful autonomous implementation or a general ranking of the providers.

An earlier transport setup run failed twice before a usable provider result:
the first SSH connection used the wrong local known-hosts context; the second
returned a nonzero transport exit without retained diagnostics. Its reservations
were preserved separately. It is not counted as a successful model experiment.

The mandatory real Qute/browser suite also exercises scoped JSON proposal →
schema-4 receipt → candidate → observation with a deterministic positive fixture.
That control verifies the connected path, but is explicitly not model-generated
pilot evidence. Before further live qualification, establish a provider that can
return a complete scoped proposal within the request limit; then measure the
actual proposal and progress to full application validation. Repeating larger
whole-issue timeouts would not address the observed capacity/latency failures.
