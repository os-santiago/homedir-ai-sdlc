# Shared GLM Flash profile

Worker and implementation use `z-ai/glm-5.3-flash` at the existing NVIDIA HTTPS
endpoint, through the shared `container/sc-agent-config.json`. Credentials remain
in the `NVIDIA_API_KEY` Actions secret and private runtime configuration, never in
this file or the image. No additional provider or LiteLLM credential is needed.

The requested initial profile uses temperature 0.5, a 1024-token output limit and
non-streaming responses. This is a bounded initial qualification setting; larger
patches may exhaust the output limit and must fail validation rather than be
published partially. Existing worker deadlines, iteration limits and review gates
remain in effect. Switching models is not proof of autonomous delivery quality.

The supplied direct API example also sets `top_p=1`. The current sc-agent-cli
provider adapter does not serialize that option; the shared profile therefore
does not claim an explicit top-p override. A direct API smoke request can exercise
the complete sample parameters, but CLI generation uses the endpoint's default
for top-p. Supporting a nondefault value requires a separate adapter change.

Merge/deploy through the existing reviewed workflow, then verify both running
image revisions, effective model selection and a bounded provider request before
resuming a real pilot. Never include a credential value in an issue or run summary.
A key shared in chat must be revoked and replaced through the secret manager;
storing it as an Actions secret does not erase the prior exposure.

The September 27 direct API smoke used the supplied numeric-comparison prompt
and all sample parameters, with hidden credential input. It reached its 40-second
transport timeout without a completed response. This does not establish invalid
credentials or model quality, and does not qualify the provider for autonomous
delivery. The seven deployment/preparation regression tests passed separately.
