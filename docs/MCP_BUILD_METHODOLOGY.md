# MCP image build methodology

The MCP images built by this repository are published with the same versioned
tag in both registries:

- `ghcr.io/rcamarda390/<image>:<upstream-version>-v<revision>`
- `docker.io/rcamarda390/<image>:<upstream-version>-v<revision>`

The current images are `agentmemory`, `iii-engine`, and `gnosis-mcp`. Their
metadata and revisions are human-edited in `images/<image>/image.yaml`.
Workflows read those files; they do not increment, commit, or push revisions.
Image-specific Docker build arguments are also defined there.

`gnosis-mcp` currently means the air-gap build: its ONNX embedding model is
pre-bundled and the image is labeled with `gnosis.airgap=true`. The air-gap
variant is not represented by a tag suffix. MCP workflows publish versioned
tags only and do not publish `latest`, `latest-airgap`, or `-build-*` tags.

Each image has an individual caller workflow. The shared
`.github/workflows/build-image.yml` workflow owns checkout, metadata parsing,
GHCR authentication with `GITHUB_TOKEN`, Docker Hub authentication with
`vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN`, and dual publishing.
Image-specific smoke tests remain in the caller workflows. Every candidate
Gnosis candidates are also scanned with Trivy for HIGH and CRITICAL
vulnerabilities, including unfixed findings, before any registry login or
publication.

The non-MCP `.github/workflows/dockerhub.yml` workflow builds the repository
root `Dockerfile` and remains outside this MCP standardization.
