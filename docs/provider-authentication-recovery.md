# Provider authentication recovery and end-to-end acceptance

The Homedir #1564 retry on worker 5be7788 reached the real worktree but stopped at provider HTTP 401 before producing a patch. Deployment consumed NVIDIA_API_KEY without forwarding the existing GitHub secret. The image also contained an unrelated embedded credential. This change removes it and aligns the image profile with the NVIDIA runtime secret.

## Deployment validation

Missing GH_TOKEN or NVIDIA_API_KEY must fail before image preparation, environment replacement or pod shutdown. Environment files are created with umask 077. Existing image preparation checks remain mandatory. No secret values should be printed during validation.

After maintainer review and merge, verify the deployed SHA and worker health. Inspect only whether the runtime credential exists, never its value. The removed embedded credential must be revoked/rotated at its issuing provider; removing it from the current source does not remove it from Git history or old image layers.

## Real pilot acceptance

1. Verify Homedir health, no active execution for #1564 and no existing linked implementation PR.
2. Requeue #1564 through the normal admission label and observe one worker execution.
3. Record admission, execution start/end, provider error category, elapsed time and terminal outcome.
4. Require a real worktree diff against the recorded base SHA, scoped validation and an actual PR linked to the issue. Provider text or process exit zero is insufficient.
5. Verify the username layout at desktop and mobile widths, PR checks and required human review. Do not automatically bypass review or merge.
6. After approved merge, verify deployment and the user-visible behavior. Record any new blocker as a separate corrective issue with evidence.

Authentication recovery alone is not proof of successful end-to-end execution. Model latency, repeated prompting, queue reconciliation delay and output quality remain to be measured on the authenticated pilot. Preserve bounded execution and avoid simultaneous retries.
