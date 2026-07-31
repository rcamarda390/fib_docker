# Customization

## Automated Version Tracking

Only the workflows in `.github/workflows/` are active GitHub Actions workflows. The similarly named YAML files in the repository root are legacy copies and do not run in GitHub Actions.

### agentmemory Version

1. **GitHub** → **Actions** → **build-agentmemory** → **Run workflow**
2. Leave **version** blank to rebuild the currently tracked package version and auto-bump the image revision, or set it to a new npm version (e.g., `0.9.27`, `0.10.0`)
3. Optionally set **image_version** if you need an exact image revision instead of the next auto-bump
4. Click **Run workflow**

The workflow updates `Dockerfile.agentmemory` and `docker-compose.yml` for you, and tags the image as `<agentmemory-version>-build-<image-version>`.

### iii-engine Version

1. **GitHub** → **Actions** → **build-iii-engine** → **Run workflow**
2. Leave **iii_version** blank to rebuild the currently tracked iii release and auto-bump the image revision
3. Set **iii_version** to a new upstream iii release to reset the image revision to `v1`
4. Optionally set **iii_image_version** if you need an exact image revision instead of the next auto-bump
5. Click **Run workflow**

The workflow updates `Dockerfile.iii-engine` and `docker-compose.yml` for you, and tags the image as `<iii-version>-airgap-<image-version>`.

### Combined Workflow

Use `build-agentmemory-mcp-all` when you want to rebuild one or both images together.

- `build_iii_engine` / `build_agentmemory` choose which images to publish
- Leave version inputs blank to reuse the tracked upstream versions
- Leave image-version inputs blank to auto-bump the tracked image revisions
- Set any version input explicitly when you want to jump to a new upstream version or force a specific image revision

## Disable Internet Features

### agentmemory — Already Offline-Ready

The agentmemory image is pre-configured for offline operation:

| Setting | Purpose | Status |
|---------|---------|--------|
| `TRANSFORMERS_OFFLINE=1` | Blocks HuggingFace downloads | ✓ Set |
| `HF_HUB_OFFLINE=1` | Belt-and-suspenders | ✓ Set |
| Pre-cached model | Xenova/all-MiniLM-L6-v2 (~23 MB) | ✓ Cached at build |
| `XENOVA_CACHE_DIR` | Points to pre-cached model | ✓ Set |

**No changes needed.** Image blocks outbound internet at runtime.

### iii-engine — Check For Internet Dependencies

iii-engine v0.22.0 generally does not require internet at runtime. If it attempts outbound connections:

1. Check `iii-config.yaml` for remote service URLs
2. Look for env vars that enable remote calls
3. Disable them in `docker-compose.yml` before deployment

Example (if needed):
```yaml
environment:
  DISABLE_PRICING_UPDATES: "true"
  DISABLE_MODEL_CHECKS: "true"
```

## Docker Hub Push Details

All images are pushed to Docker Hub (not GHCR) to integrate with Artifactory's remote proxy caching.

### Workflow Secrets Required

Both workflows need:
- `DOCKERHUB_USERNAME` — Docker Hub username
- `DOCKERHUB_TOKEN` — Docker Hub personal access token

Configure in: **Repository Settings** → **Secrets and variables** → **Actions**

Token scope: `read:packages`, `write:packages`

### Updating Docker Hub Image Names

If you change the repository owner or namespace, update these files:
- `.github/workflows/build-iii-engine.yml`
- `.github/workflows/build-agentmemory.yml`
- `.github/workflows/build-agentmemory-mcp-all.yml`

Replace `${{ secrets.DOCKERHUB_USERNAME }}` with hardcoded username if needed, or update the secret name to match your setup.

### Image Availability Timeline

| Step | Time | Details |
|------|------|---------|
| Build completes | Immediate | Image available at `docker.io/rcamarda390/...` |
| First Artifactory pull | 30-60s | Artifactory remote proxy fetches from Docker Hub |
| Cached in Artifactory | 5-10min | Subsequent pulls are instant |

After build completes, you can pull from Artifactory. First pull may take a moment as Artifactory caches it.

## Upstream Contributions

### To rohitg00/agentmemory

If you improve the Docker build or offline support, consider upstreaming:

```bash
# Fork https://github.com/rohitg00/agentmemory
# Create branch: feature/air-gap-ready
# Add: Dockerfile, cache-models.js, docker-entrypoint.sh, workflows
# Submit PR
```

### To iii-hq/iii

If v0.22.0 needs adjustments for air-gapped environments:

```bash
# Open issue: "Support air-gapped deployment (disable internet features)"
```
