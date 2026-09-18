# Explicit inference profiles and literal source context

`request_proposal(..., profile=...)` accepts reviewed profiles rather than arbitrary
provider parameters. `default` retains the original non-streaming request with
temperature 0.2 and 4,096 total output tokens. Model-specific profiles reject a
different model before starting the helper:

| Profile | Exact model | Additional requested settings |
| --- | --- | --- |
| `lightning-json-v1` | `nvidia/nemotron-3.5-lightning-30b-a3b` | JSON object; `enable_thinking=false` |
| `lightning-reasoned-json-v1` | same Lightning identifier | JSON object; thinking enabled; `reasoning_budget=1024` |
| `deepseek-low-json-v1` | `deepseek-ai/deepseek-v4-flash-0731` | JSON object; `thinking=true`, `reasoning_effort=low` |

All profiles retain the maximum 120-second request, 4,096-token total output
setting, fixed HTTPS endpoint, redirect refusal and credential isolation.
Reasoning options are requests to the provider, not a locally enforced reasoning
token guarantee. The independent local deadline still bounds a slow response.
JSON mode does not replace the exact-edit parser or establish semantic validity.

The result and durable proposal evidence record the profile, bounded finish
reason and SHA-256 of the canonical HTTP request body. The hash includes model,
messages and generation options, but excludes the authorization header. Rotating
the credential does not change it. Reasoning text is discarded; only final
content and numeric usage are retained. The existing evidence request hash still
identifies messages alone, so it is intentionally distinct from the payload hash.

`generate_proposal(..., context_format='literal-excerpts-v1')` displays selected
source as literal text with file/excerpt headings. Supported policy inputs are
file text or a bounded `row_excerpts` list. Prior proposal JSON is also displayed
literally instead of being nested in another JSON string. Unknown formats,
unsupported shapes, unsafe paths and existing size-limit violations are rejected.
The default `json-v1` format remains available. The caller must reflect the selected
format in its plan identity; evidence records the format and exact message hash.

This addresses observed double escaping of source newlines/quotes. It does not
repair model output, infer missing counts, relax scope, accept partial JSON or
alter the source. Each returned edit must still match the immutable original
file exactly; candidates remain untrusted until independently validated.

Protocol rejections now retain a bounded diagnostic in both the receipt evidence
and the returned result. Missing fields identify the edit index; count mismatches
report expected and observed counts. Diagnostics never echo proposed source text.
The trusted caller can feed this diagnostic into the remaining attempt instead
of sending only a generic failure. No automatic output repair is introduced.

## References

NVIDIA documents [Lightning reasoning and structured output controls](https://docs.nvidia.com/nim/large-language-models/2.0.10/get-started/advanced/get-started-nemotron-3.5-lightning.html)
and shows the hosted endpoint's `reasoning_budget` in its [build example](https://build.nvidia.com/nvidia/nemotron-3.5-lightning-30b-a3b/build).
The [DeepSeek hosted example](https://build.nvidia.com/deepseek-ai/deepseek-v4-flash-0731/build)
uses `chat_template_kwargs.thinking` and `reasoning_effort`; its
[model card](https://build.nvidia.com/deepseek-ai/deepseek-v4-flash-0731/modelcard)
lists low/high/max effort modes. These references motivated experiments; observed
results, not capability descriptions, determine qualification.

## Shadow experiment design, 2026-09-18

Each explicitly changed profile/plan received a separate two-attempt, 250-second
edit ledger. Each request reserved 125 seconds and could run for at most 120.
An unsuccessful attempt used only the remaining attempt in that experiment;
there was no automatic model fallback, budget extension or production requeue.
All experiments used Homedir #1564 at current main
`e8ca4b42ea358a693aea9e8b8212f4dafe712888`, the same requirement body and the same
CSS plus five row excerpts (11,038 bytes when serialized as context JSON).
The NVIDIA credential stayed on the VPS. No model received tools or publisher
credentials. Profile comparisons occurred sequentially while production stayed
on merged ai-sdlc revision `272591d9a920b1f779e7b8ce0a9288eae8ca18f1`.

The literal format also adds explicit encoding/all-occurrence instructions, so
comparisons are not controlled measurements of serialization alone. The sample
is too small to infer production reliability or a general provider ranking.

## Observed results

| Model/profile | Context | Attempt | Provider seconds | Independent outcome |
| --- | --- | --- | --- | --- |
| Lightning, thinking off | JSON | 1 | 24.622 | Applied; component rejected |
| Lightning, thinking off | JSON | 2 | 31.724 | Edit schema rejected |
| Lightning, reasoning budget 1,024 | JSON | 1 | 61.932 | Required edit fields missing |
| Lightning, reasoning budget 1,024 | JSON | 2 | 41.755 | Over-escaped source did not match |
| Lightning, reasoning budget 1,024 | Literal | 1 | 47.545 | Incorrect occurrence counts |
| Lightning, reasoning budget 1,024 | Literal | 2 | 39.114 | Applied; component rejected |
| DeepSeek, low effort | Literal | 1 | 120.072 | Request timeout/transport failure |

All six Lightning requests returned `finish_reason=stop`. That did not establish
protocol conformance or quality. The two applicable proposals failed `ellipsis`,
`full-name-accessible`, `no-collision` and `no-horizontal-overflow` at both 1024px
and 375px. The first introduced `max-width:0`, hiding names, and omitted several
row variants. The literal-context retry corrected occurrence handling sufficiently
to apply, but did not satisfy the visual requirements.

The DeepSeek experiment stopped after its first failure with one 125-second
reservation remaining. Three Lightning ledgers each consumed two reservations.
Across this qualification session, seven requests consumed 875 reserved edit
seconds across four explicitly different experiments. This is not seven retries
of one production issue admission. No budget was refunded or extended.

The sanitized aggregate observation SHA-256 is
`3bbdabbd2cb020d8e52a2a180527b326f3af983aa15f96bce882ecac4a24252e`.
The two candidate snapshot hashes are
`c676d09bb93cdcdced3bafaf69df6a8c085707cddd7a2d47b8197a21541cd859`
and `ab1787bcf8b79755e415ff7a499d174e91f6522b81131dfd5aa9f34d62259681`.
Their component observation hashes are respectively
`1afba84c0da810c16d170d97982b1392624b3fa6c0cf2779c11e4e2792077f2f`
and `d84249ecbc539e16ba2f3526f5f508ee9721e6cabf8622555c4977f2c1a65430`.
The reviewed validator image was
`sha256:691d16cc13cd918730e2868f5346fcd6ba32563876de4a1373ee297a719b705e`.

All four ledgers remained `untrusted`, with no checkpoint or publication. No
remote helper remained alive at reconciliation. Validation reservations remain
unchanged because these are still offline component probes, not scheduled
validation steps. The newly improved diagnostic messages were added after the
experiments; their effect on model repair has not yet been qualified live.

## Decision

No tested profile is qualified for autonomous implementation. Explicit settings
and literal context let us obtain and inspect proposals within the deadline, but
the decisive gate remains correctness. The next increment should make the plan
and edit targets less ambiguous, cover every linked/unlinked row, and use precise
validator/protocol feedback. It must preserve visible names and score layout;
the requirement's `max-width / min-width:0` wording cannot justify hiding names.
Do not promote a profile based only on latency or `finish_reason=stop`, increase
whole-issue timeouts, or claim #1564 resolved from these results. Full application
validation, publication and production observation remain pending under #75.
