# Customization

## Bump Versions

### agentmemory Version (Easy — No Code Changes)

Each time you want to rebuild with a new agentmemory version:

1. **GitHub** → **Actions** → **build-agentmemory** → **Run workflow**
2. Set **version** to any npm version (e.g., `0.9.27`, `0.10.0`)
3. Click **Run workflow**

No code edits needed.

### iii-engine Version (Requires Code Change)

If upgrading to a different iii-engine version, or rebuilding the same iii release with image-only changes:

1. Edit `Dockerfile.iii-engine`:
   ```dockerfile
   ARG III_VERSION=0.X.Y    # Upstream iii release
   ARG III_IMAGE_VERSION=vN # Bump when the image changes for the same iii release
   ```

2. Rebuild with the combined image tag format `<iii-version>-airgap-<image-version>`

3. Update `docker-compose.yml`:
   ```yaml
   image: ${ARTIFACTORY_REGISTRY:-ghcr.io/rcamarda390}/iii-engine:0.X.Y-airgap-vN
   ```

4. Commit and push to `main` (auto-triggers build)

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
- `.github/workflows/build-iii-engine.yml` → line 56
- `.github/workflows/build-agentmemory.yml` → lines 44-45
- `.github/workflows/build-agentmemory-mcp-all.yml` → lines 62, 95-96

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
