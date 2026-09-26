# Credential remediation and deployment prerequisite

## Current provider configuration

Worker and implementation now share `container/sc-agent-config.json` and the
`nvidia` profile. Both use `NVIDIA_API_KEY`; `LITELLM_API_KEY` is no longer required
by production deployment. The implementation writes its credential only into its
private runtime configuration and rejects stale provider endpoints or profiles.
The historical LiteLLM key still needs revocation; provider unification does not
invalidate leaked credentials. The procedure below records the earlier #105
rollout and its original prerequisite, superseded by this configuration change.

For deployment, update the existing `NVIDIA_API_KEY` secret with a valid replacement
if needed, merge the reviewed configuration PR, and verify the deployed revision
and provider access. Do not provision a LiteLLM key for this route.

## Historical #105 remediation procedure

Tracking incident: #98. Repository cleanup does not revoke a credential and does
not remove it from historical commits, published images, logs or existing clones.
The September 23 cleanup removes full values, prefixes and credential-shaped
examples from current documentation and removes the bundled LiteLLM keys.
**Provider revocation has not been verified. The incident must remain open.**

Before merging/deploying the credential-injection change, the credential owner must:

1. Revoke the exposed NVIDIA and LiteLLM credentials at their providers, review
   available usage records, and issue replacements with the necessary scope.
2. Update the repository's `NVIDIA_API_KEY` Actions secret and create
   `LITELLM_API_KEY` with the replacement LiteLLM credential. Never paste values
   into an issue, PR, chat, command argument or documentation.
3. Deploy through the normal reviewed workflow and verify provider authentication
   from the trusted runtime. A health endpoint alone does not verify model access.
4. Record revocation time and non-secret key identifiers in #98. Rebuild images
   and address retained copies according to the incident process. History rewriting
   requires coordinated maintenance and is not performed by this cleanup.

Deployment validates all three required runtime secrets before pulling replacements
or stopping the current pod. The implementation container receives only its
`LITELLM_API_KEY` via environment forwarding. Its entrypoint reads the value using
`jq env`, writes the private runtime configuration with umask 077, and refuses to
start its LiteLLM profile without the variable. No working credential is bundled.
The current LiteLLM model and endpoint are preserved.

## Secret scanning

The workflow uses the [Gitleaks CLI](https://github.com/gitleaks/gitleaks) 8.30.1,
with a pinned release checksum and no organization license dependency. It scans
the complete tracked tree plus added content in commits after
`74c48e74147cbd7dd4f34fbb4dbf3bedd37ff506`. The historical boundary avoids treating
known, still-exposed old commits as new findings; it does not claim clean history.
Newly added then deleted credentials are still detected in the commit scan.

Default rules are extended with a NVIDIA rule. Logs are fully redacted; raw
findings are not uploaded. Inline allow comments and repository ignore files do
not suppress detections. A generated synthetic-token canary checks that the NVIDIA
rule actually rejects a leak. Changes to the workflow, rule configuration or
historical boundary require security review, like other repository-owned controls.
