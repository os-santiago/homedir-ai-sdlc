# GitHub Actions Workflows

## Active Workflows

### Production Deployment

#### `deploy-production.yml` ⭐ **PRIMARY**
- **Purpose**: Build and deploy AI-SDLC to production (containerized)
- **Triggers**: 
  - Push to `main` (paths: `platform/`, `dashboard/`, `container/`)
  - Manual via workflow_dispatch
- **Jobs**:
  1. Build worker container → `ghcr.io/os-santiago/homedir-ai-sdlc/worker:latest`
  2. Build dashboard container → `ghcr.io/os-santiago/homedir-ai-sdlc/dashboard:latest`
  3. Deploy to VPS (if secrets configured)
- **Status**: ✅ Active
- **Docs**: [docs/deployment/containerized-deployment.md](../../docs/deployment/containerized-deployment.md)

### CI/Testing

#### `ci.yml`
- **Purpose**: Basic CI checks
- **Triggers**: Pull requests
- **Status**: ✅ Active

#### `test-autonomous-worker.yml`
- **Purpose**: Test autonomous worker functionality
- **Triggers**: Manual via workflow_dispatch
- **Status**: ✅ Active

### Future Architecture

#### `images.yml`
- **Purpose**: Build Go microservices containers (future architecture)
- **Triggers**: Push to `main` (paths: `components/`, `internal/`, `go.mod`)
- **Components**: admission-controller, orchestrator, worker, release-manager
- **Status**: ✅ Active (for future-go/ project)

---

## Disabled Workflows

These workflows have been disabled because they are replaced by `deploy-production.yml`:

### `build-worker-image.yml.disabled`
- **Reason**: Replaced by `deploy-production.yml`
- **Issues**: 
  - Pushed to Quay.io without credentials → always failed
  - Manual deployment approach (deprecated)
- **Disabled**: 2026-08-15

### `deploy-worker.yml.disabled`
- **Reason**: Replaced by `deploy-production.yml`
- **Issues**:
  - Used SCP to copy scripts directly to VPS (not containerized)
  - Manual approach conflicts with immutable deployments
- **Disabled**: 2026-08-15

### `events-service-release.yml.disabled`
- **Reason**: Events service not production-ready
- **Issues**:
  - Workflow file has configuration errors
  - Service dependencies not complete
- **Disabled**: 2026-08-15
- **Note**: Re-enable when events-service is ready for production

---

## Workflow Migration

### Old Approach (Deprecated)
```
Git Push → SCP scripts to VPS → systemd restart
```
**Problems:**
- ❌ Configuration drift
- ❌ No version control of deployed state
- ❌ Manual steps required
- ❌ No rollback mechanism

### New Approach (Current)
```
Git Push → Build Containers → Push to Registry → Deploy via Podman
```
**Benefits:**
- ✅ Immutable deployments
- ✅ Git commit = Container version
- ✅ Instant rollback
- ✅ Zero manual steps
- ✅ 100% reproducible

---

## Secrets Required

For `deploy-production.yml` to deploy to VPS, configure these repository secrets:

- `VPS_HOST`: IP or hostname of VPS (e.g., `72.60.141.165`)
- `VPS_USER`: SSH user for deployment (e.g., `root`)
- `VPS_SSH_KEY`: Private SSH key for authentication

**Setup Guide**: [docs/deployment/github-secrets-setup.md](../../docs/deployment/github-secrets-setup.md)

**Note**: Without these secrets, the workflow will:
- ✅ Build containers successfully
- ✅ Push to ghcr.io
- ⏭️ Skip VPS deployment step

---

## Re-enabling Disabled Workflows

If you need to re-enable a disabled workflow:

```bash
cd .github/workflows/
git mv workflow-name.yml.disabled workflow-name.yml
git commit -m "chore: re-enable workflow-name"
git push
```

**Before re-enabling:**
1. Verify the workflow doesn't conflict with active workflows
2. Ensure all required secrets/variables are configured
3. Test with `workflow_dispatch` before enabling automatic triggers

---

## Troubleshooting

### Workflow Failing: "missing server host"
**Cause**: `VPS_HOST` secret not configured  
**Solution**: [docs/deployment/github-secrets-setup.md](../../docs/deployment/github-secrets-setup.md)

### Workflow Failing: "authentication required" (Quay.io)
**Cause**: Trying to push to Quay.io without credentials  
**Solution**: This was in old workflows. Use `deploy-production.yml` which pushes to ghcr.io

### Multiple Workflows Running
**Cause**: Path overlap between workflows  
**Solution**: Check `paths:` filters in each workflow's `on:` section

---

## References

- GitHub Actions Docs: https://docs.github.com/en/actions
- Container Registry: https://github.com/orgs/os-santiago/packages?repo_name=homedir-ai-sdlc
- Deployment Guide: [docs/deployment/containerized-deployment.md](../../docs/deployment/containerized-deployment.md)
