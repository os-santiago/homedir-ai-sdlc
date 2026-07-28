# GitOps deployment

`base` defines topology, security and component identities. Overlays define
environment configuration and image references.

```bash
kustomize build deploy/gitops/overlays/development
kustomize build deploy/gitops/overlays/production
```

CI builds, tests, scans and publishes each component image. Promotion updates
immutable image digests in an environment overlay through a pull request.
Runtime mutation is prohibited; rollback is a Git revert or reviewed digest
change.

No literal credentials belong in Git. Production must use External Secrets,
SOPS or Sealed Secrets.

The base initially co-locates four containers in one pod. When concurrency
requires horizontal scaling, the worker moves to a dedicated Deployment without
changing contracts.
