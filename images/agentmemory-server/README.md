# AgentMemory image

This image intentionally follows the upstream `rohitg00/agentmemory` deployment pattern as closely as possible.

## Upstream components

- AgentMemory: `0.9.29`
- iii engine: `0.11.2`
- iii SDK: `0.11.2`
- Runtime base: `node:22-slim`

The Dockerfile uses the official `iiidev/iii` image as a build stage and copies `/app/iii` into the final AgentMemory image, matching upstream. AgentMemory itself is installed from npm at build time.

The local repository only adds our image metadata/versioning and publication workflow. Security remediation should be applied only after the upstream-equivalent image is built and scanned by Xray.

## Build metadata

`image.yaml` controls the upstream AgentMemory version, iii version, and local revision/tagging used by the reusable GitHub Actions workflow.

The first build of a new upstream version is published as `UPSTREAM_VERSION-v1`; subsequent security or packaging revisions increment the `vN` suffix without changing the upstream version.

## Runtime data

Persist `/data` for AgentMemory state and the generated HMAC secret. Port `3111` exposes the AgentMemory HTTP service and health endpoint.
