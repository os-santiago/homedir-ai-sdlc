# Runtime recovery after sc-agent-cli #395

The production worker remained on homedir-ai-sdlc `0cf0b0f` because the #68 deployment failed when Quay rejected pushes in read-only mode. Its sc-agent-cli revision was `95174be`, which forced streaming despite `model.stream=false`.

The #1564 pilot on that version ran from 16:42:57 to 17:03:08 UTC, failed with five empty responses across fifteen iterations, and produced no diff. GitHub subsequently rejected comments on a historical issue with more than 2500 comments, aborting reconciliation before admission.

## Corrected execution fixture

The merged sc-agent-cli revision `d78def29e8f84502f63218ac8ce078c8a4a3f965` was cloned and built in a temporary directory in the existing worker. The installed production binary was not replaced.

A temporary file containing `before` was passed to the corrected CLI with a request to read it, replace the word with `after`, and verify it using the file tool. With provider NVIDIA, model `poolside/laguna-xs-2.1`, temperature 0.2, non-streaming transport, and a 2048-token response limit, the CLI exited zero in 50.28 seconds and the final bytes exactly matched `after`. No Homedir source or GitHub issue was changed by that fixture.

The worker image now pins that exact CLI revision and selects the validated model and transport. Its response limit is 4096 tokens to allow larger repository edits; the successful small fixture used 2048. This fixture proves basic tool execution, not acceptance of Homedir #1564 or end-to-end operation.

## Notification behavior

Issue-comment errors remain visible in logs but no longer abort worker processing. A local digest of the last successfully posted message suppresses identical consecutive comments on the same issue. Failed attempts remain eligible for retry; a different message or issue is sent normally. The cache contains hashes, not message bodies. Deleting or losing the cache can cause a repeated comment, so it is not an exactly-once delivery mechanism.

## Deployment and pilot gate

After reviewed merge, confirm the deployed worker image SHA and the pinned CLI SHA, then confirm the effective profile is non-streaming. Verify no existing execution or PR for #1564 before requeueing it. Require a real repository diff, scoped validation, an issue-linked PR, required review, deployment, and visual verification before declaring end-to-end success. An image registry failure must continue to preserve the existing deployment.
