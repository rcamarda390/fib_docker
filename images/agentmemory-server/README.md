# agentmemory-server

A single, self-contained Docker image for air-gapped [agentmemory](https://github.com/rohitg00/agentmemory)
deployments. The image bundles both agentmemory and its compatible
[iii](https://github.com/iii-hq/iii) engine — there is no separate iii
container to run or wire up.

```
agentmemory-server Docker image
        ↑
        │ HTTP :3111
        │
@agentmemory/mcp inside devcontainers
        ↑
        │ MCP
        │
Cline / Codex / other MCP clients
```

`@agentmemory/mcp` is installed software, not just a JSON config file. The
MCP client configuration below launches that executable and tells it which
agentmemory server to talk to.

The published image name is `agentmemory` (unchanged from before this
directory was consolidated), built from `images/agentmemory-server/`. The
directory was renamed for clarity; the registry name was kept to avoid
breaking existing Artifactory import configs and pull references.

## Architecture

```
EC2 Linux host
└── Docker container: agentmemory (this image)
    ├── agentmemory (Node, npm-installed, pinned version)
    ├── iii engine (binary, copied in from iiidev/iii, pinned compatible version)
    └── persistent /data

VS Code devcontainers
└── @agentmemory/mcp executable
    └── connects over HTTP to the agentmemory container on :3111
```

The container's main process is the `agentmemory` CLI (not a raw server
script). On startup the CLI finds the `iii` binary on `PATH`, spawns it
itself, waits for it to come up, and only then starts its own REST/MCP-HTTP
server on port 3111 — the same pattern
[upstream's own single-container deploy templates](https://github.com/rohitg00/agentmemory/tree/main/deploy)
(Fly, Railway, Render, Coolify) use. Only port 3111 is published; the
iii engine's internal ports (streams on 3112, worker/telemetry websocket on
49134) and agentmemory's real-time viewer (3113) stay inside the container.

### Why iii 0.11.2, not the latest iii release

agentmemory 0.9.28 pins its `iii-sdk` client dependency to the exact version
`0.11.2` (no caret). iii-sdk 0.11.6 changed engine routing and broke
agentmemory's REST mount (upstream issue #555, fixed in PR #567 by pinning
back). The iii engine version is a dependency of agentmemory, not an
independent release to chase — `images/agentmemory-server/image.yaml`'s
`build_args.III_VERSION` should only change when agentmemory's own `iii-sdk`
pin changes, never just because a newer `iii-hq/iii` tag exists.

### Why agentmemory 0.9.28, not 0.9.29

Upstream's `main` branch and its own deploy Dockerfiles already reference
`0.9.29`, but as of this writing `0.9.29` has a CHANGELOG entry and a bumped
`package.json` on GitHub, but was never published to npm (no npm tag, no git
release tag). Building against it would fail at `npm ci`. Re-pin once it is
actually published — see "Updating the pinned version" below.

## Persistent data

The container persists everything under `/data`: agentmemory's memories
(stored through iii's file-backed state/stream workers) and the generated
HMAC secret. Use a named volume or bind mount:

```bash
docker run -d \
  --name agentmemory-server \
  --restart unless-stopped \
  -p 3111:3111 \
  -v agentmemory-data:/data \
  <internal-registry>/agentmemory:<version>
```

Do not point `/data` at anything inside a devcontainer — devcontainers are
disposable and are not where memories live. A `docker-compose.yml` with the
same shape is included in this directory for reference.

## The HMAC secret

agentmemory generates a persistent HMAC secret on first boot and stores it
at `/data/.agentmemory-secret` (override the path with
`AGENTMEMORY_SECRET_FILE`). The container prints it to its logs exactly once,
on the boot where it's generated:

```
docker logs agentmemory-server 2>&1 | grep -A2 AGENTMEMORY_SECRET
```

An administrator needs to capture that value once and distribute it to
developers for their devcontainer MCP client configs (see below). To rotate
the secret, delete the secret file from the persistent volume and restart
the container — it will generate and print a new one.

## Devcontainer MCP client

Developer devcontainers do **not** need the full agentmemory server or the
`iii` engine. They need the much smaller `@agentmemory/mcp` package, which
installs an `agentmemory-mcp` executable that proxies MCP calls to the
shared server over HTTP.

The devcontainer image needs:

- Node.js >= 20 (agentmemory 0.9.28's requirement; check
  `images/agentmemory-server/package.json` if the pinned version changes)
- `@agentmemory/mcp` installed globally and pinned to the same version as
  the server:

  ```dockerfile
  RUN npm install -g @agentmemory/mcp@0.9.28
  ```

This repository does not contain a devcontainer image to modify — add the
line above to whichever devcontainer repository/image the team's VS Code
devcontainers actually build from.

### MCP client configuration

```json
{
  "mcpServers": {
    "agentmemory": {
      "command": "agentmemory-mcp",
      "env": {
        "AGENTMEMORY_URL": "http://<agentmemory-host>:3111",
        "AGENTMEMORY_SECRET": "<secret>",
        "AGENTMEMORY_FORCE_PROXY": "1"
      }
    }
  }
}
```

`<agentmemory-host>` depends on how the devcontainer reaches the server —
`localhost` inside a devcontainer refers to the devcontainer itself, never
the EC2 host or another container, so it never works here. Two supported
options:

**Preferred — shared Docker network.** Attach the agentmemory server
container and the devcontainers to the same Docker network so container DNS
resolves the server by name:

```bash
docker network create agentmemory-net
docker run -d --name agentmemory-server --network agentmemory-net \
  -v agentmemory-data:/data <internal-registry>/agentmemory:<version>
```

and add the devcontainer to `agentmemory-net` (e.g. via
`.devcontainer/devcontainer.json`'s `runArgs: ["--network=agentmemory-net"]`
or an equivalent Compose network). Then use:

```
AGENTMEMORY_URL=http://agentmemory-server:3111
```

**Alternative — host networking.** If devcontainers can't join the server's
Docker network, publish the port on the EC2 host (`-p 3111:3111`, already in
the `docker run` example above) and point devcontainers at a host address
they can resolve — the host's private IP or an internal DNS name your team
maintains, not `localhost`:

```
AGENTMEMORY_URL=http://<ec2-host-address>:3111
```

## Offline operation

`@xenova/transformers` local embeddings are pre-cached at build time
(`cache-models.js`) so the container never reaches out to Hugging Face at
runtime. `TRANSFORMERS_OFFLINE=1` and `HF_HUB_OFFLINE=1` are set in the
image. The runtime does not use `npm`/`npx`/`corepack` — they're removed
from the image entirely — and does not need GitHub or Docker Hub access at
container start; those are only touched at build time (`docker build` runs
somewhere with internet access, and the built image ships through
Artifactory/manual import into the air-gapped environment, same as this
repo's other MCP images).

If agentmemory ever migrates to `@huggingface/transformers` (already true on
its unreleased `main` branch, targeting 0.9.29) `cache-models.js` and the
cached model directory will need updating to match — check
`src/providers/embedding/local.ts` upstream when bumping past 0.9.28.

## Updating the pinned version

1. Confirm the new `@agentmemory/agentmemory` version is actually published
   (`npm view @agentmemory/agentmemory versions`), not just tagged on GitHub.
2. Check what `iii-sdk` version it pins (`npm view @agentmemory/agentmemory@<version> dependencies.iii-sdk`)
   and update `build_args.III_VERSION` in `image.yaml` to match — do not use
   a newer `iii-hq/iii` release on its own.
3. Update `package.json`'s `@agentmemory/agentmemory` version and regenerate
   `package-lock.json` with `npm install` (or `npm ci` after hand-editing,
   then verify).
4. Set `upstream_version` in `image.yaml`. The build workflow auto-increments
   and commits `revision`; leave it as-is when bumping `upstream_version` —
   the shared workflow resets it to 1 automatically.
5. Trigger `build-agentmemory-server.yml` manually — image builds are
   workflow_dispatch only, not automatic on push/PR/schedule.

## Registry publishing

Published to both registries via the shared `.github/workflows/build-image.yml`:

- `ghcr.io/rcamarda390/agentmemory:<upstream-version>-v<revision>`
- `docker.io/rcamarda390/agentmemory:<upstream-version>-v<revision>`

`DOCKERHUB_USERNAME` is a repository variable; `DOCKERHUB_TOKEN` is a
repository secret. GHCR uses the workflow's `GITHUB_TOKEN`. See
[`docs/MCP_BUILD_METHODOLOGY.md`](../../docs/MCP_BUILD_METHODOLOGY.md) for
the full release process shared with this repository's other MCP images.
