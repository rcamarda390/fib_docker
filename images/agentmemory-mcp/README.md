# agentmemory-mcp

This folder contains Docker builds for **iii-engine v0.22.0** (**image tag `0.22.0-airgap-v1`**) and **agentmemory v0.9.26** — optimized for air-gapped AWS EC2 deployment.

## What This Does

Two complementary Docker images:

1. **iii-engine:0.22.0-airgap-v1** — WebSocket backend service
   - Source: Pre-built binary from iii GitHub releases
   - Base: distroless
   - Ports: 3111 (REST), 3112 (streams), 49134 (WebSocket bridge)

2. **agentmemory:0.9.26** — MCP server + viewer
   - Source: `@agentmemory/agentmemory` npm package
   - Build stages: npm-install → model-cache → production
   - Pre-cached: Xenova/all-MiniLM-L6-v2 (~23 MB)
   - Runtime: Offline-only (TRANSFORMERS_OFFLINE=1, HF_HUB_OFFLINE=1)
   - Port: 3113 (HTTP)

## Architecture

```
GitHub Actions (build) 
    ↓ (Docker Hub push)
Staging Environment (pull + vet)
    ↓ (Artifactory scan)
Artifactory Registry (approved)
    ↓ (air-gap transfer)
Air-Gapped EC2 (docker compose up)
```

## Image Names (Docker Hub)

- `docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1` (Docker Hub)
- `docker.io/rcamarda390/agentmemory:0.9.26` (Docker Hub, also `:latest`)

Images are cached through Artifactory's remote proxy:
- `artifactory.foobar.com/docker-remote/rcamarda390/iii-engine:0.22.0-airgap-v1`
- `artifactory.foobar.com/docker-remote/rcamarda390/agentmemory:0.9.26`

Pull from Docker Hub directly or through Artifactory (auto-cached on first pull).

## Workflows

Three GitHub Actions workflows control builds:

### 1. `build-iii-engine.yml`

Builds iii-engine independently.

- **Trigger:** Push to `main` when `Dockerfile.iii-engine` or `iii-config.yaml` changes, or manual dispatch
- **Duration:** ~3 minutes
- **Output:** `docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1`

### 2. `build-agentmemory.yml`

Builds agentmemory independently.

- **Trigger:** Manual dispatch only (`workflow_dispatch`)
- **Input:** `version` (default: `0.9.26`) — any npm version
- **Duration:** ~10-15 minutes (includes HuggingFace model caching)
- **Output:** `docker.io/rcamarda390/agentmemory:<version>` and `:latest`

### 3. `build-agentmemory-mcp-all.yml`

Orchestrator — builds iii-engine and/or agentmemory together.

- **Trigger:** Manual dispatch only
- **Inputs:**
  - `build_iii_engine` (true/false, default: true)
  - `build_agentmemory` (true/false, default: true)
  - `agentmemory_version` (default: 0.9.26)
- **Behavior:** Builds in sequence (iii-engine first, then agentmemory); stops if iii-engine fails
- **Use case:** "Build everything at once"

## Quick Start

### 1. Trigger iii-engine Build

**GitHub** → **Actions** → **build-iii-engine** → **Run workflow** (or auto-triggers on push)

Build output: `docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1`

### 2. Trigger agentmemory Build

**GitHub** → **Actions** → **build-agentmemory** → **Run workflow**

Set version (default `0.9.26`). Build output: `docker.io/rcamarda390/agentmemory:0.9.26` + `:latest`

### 3. Pull & Vet in Staging

On a machine with internet access:

```bash
docker pull docker.io/rcamarda390/iii-engine:0.22.0-airgap-v1
docker pull docker.io/rcamarda390/agentmemory:0.9.26

# Run docker compose to test
docker compose up -d
docker compose ps
docker compose logs
```

### 4. Deploy to Air-Gapped EC2

After Artifactory security scan approves:

```bash
export ARTIFACTORY_REGISTRY=artifactory.foobar.com/docker-remote/rcamarda390
docker pull $ARTIFACTORY_REGISTRY/iii-engine:0.22.0-airgap-v1
docker pull $ARTIFACTORY_REGISTRY/agentmemory:0.9.26
docker compose up -d
```

## Ports

| Port | Service | Protocol |
|---|---|---|
| 3111 | iii-engine REST | HTTP |
| 3112 | iii-engine streams | HTTP |
| 49134 | iii-engine WebSocket | WS (internal to agentmemory) |
| 3113 | agentmemory viewer | HTTP |

## Pre-Cached Model

Xenova/all-MiniLM-L6-v2 (~23 MB) is pre-cached at build time. At runtime:
- `TRANSFORMERS_OFFLINE=1` blocks outbound HuggingFace calls
- `HF_HUB_OFFLINE=1` (belt-and-suspenders)
- Model served from container cache
- **No internet required at runtime**

## Volumes

| Volume | Service | Purpose |
|---|---|---|
| `iii-data` | iii-engine | Engine state (KV store, streams) |
| `agentmemory-data` | agentmemory | Persistent HMAC secret |

## See Also

- [CUSTOMIZATION.md](CUSTOMIZATION.md) — Version bumping, disabling internet features
- [iii-engine](https://github.com/iii-hq/iii) — v0.22.0 release
- [agentmemory](https://github.com/rohitg00/agentmemory) — npm package
