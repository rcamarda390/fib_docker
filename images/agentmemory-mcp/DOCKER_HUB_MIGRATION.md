# Docker Hub Migration for agentmemory-mcp

## Why Docker Hub?

This project uses Docker Hub for image hosting (instead of GHCR) to align with existing infrastructure:

- **Artifactory Integration:** The air-gap deployment flow pulls images through Artifactory's remote proxy
- **Existing Pattern:** gnosis-mcp already uses this workflow successfully
- **Proxy Configuration:** Artifactory's `docker-remote` remote repository is configured to cache images from Docker Hub

## Deployment Flow

```
GitHub Actions (build to Docker Hub)
    ↓
Docker Hub (rcamarda390/iii-engine, rcamarda390/agentmemory)
    ↓
Artifactory Remote Proxy (auto-caches on first pull)
    ↓
Air-Gapped EC2 (pulls from artifactory.foobar.com/docker-remote/...)
```

## Image Names

| Service | Docker Hub | Artifactory |
|---------|------------|-------------|
| iii-engine | `docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1` | `artifactory.foobar.com/docker-remote/rcamarda390/iii-engine:0.22.0-airgap-v1` |
| agentmemory | `docker.io/rcamarda390/agentmemory:0.9.26` | `artifactory.foobar.com/docker-remote/rcamarda390/agentmemory:0.9.26` |

## Secrets Required

Both GitHub Actions secrets must be configured in the repository:
- `DOCKERHUB_USERNAME` — Docker Hub account username
- `DOCKERHUB_TOKEN` — Docker Hub personal access token (PAT) with `read` and `write:packages` scopes

See `.github/workflows/build-gnosis-mcp.yml` for reference pattern.

## Troubleshooting

### Images don't appear in Artifactory
1. Verify images built successfully in Docker Hub: `docker pull docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1`
2. Verify Artifactory's `docker-remote` remote repository points to `https://registry-1.docker.io` (Docker Hub)
3. Manually pull through Artifactory to warm cache: `docker pull artifactory.foobar.com/docker-remote/rcamarda390/iii-engine:0.22.0-airgap-v1`

### Workflows fail with permission errors
1. Verify `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets are set in Repository Settings → Secrets and variables → Actions
2. Verify Docker Hub PAT has `read:packages` and `write:packages` scopes
3. Check Docker Hub account has pull/push access to `rcamarda390` namespace (should own or be collaborator)
