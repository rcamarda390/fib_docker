# MCP image build methodology

The MCP images built by this repository are published with the same versioned
tag in both registries:

- `ghcr.io/rcamarda390/<image>:<upstream-version>-v<revision>`
- `docker.io/rcamarda390/<image>:<upstream-version>-v<revision>`

The current images are `agentmemory`, `gnosis-mcp`, `atlassian-mcp`,
`bifrost-mcp`, `headroom-mcp`, and `sqz-mcp`. Their metadata is human-edited
in `images/<image-dir>/image.yaml`. Published MCP builds automatically
increment and commit the image revision. When `upstream_version` changes, the
revision resets to `1`; pull request validation builds do not consume
revisions. Image-specific Docker build arguments are also defined there.

`agentmemory` is built from `images/agentmemory-server/`: agentmemory and its
compatible `iii` engine binary are bundled into one image, there is no
separate `iii-engine` image or workflow. `images/agentmemory-server/image.yaml`'s
`build_args.III_VERSION` tracks the exact iii version agentmemory's own
`iii-sdk` dependency pins — it is not bumped independently just because a
newer `iii-hq/iii` release exists. See
[`images/agentmemory-server/README.md`](../images/agentmemory-server/README.md)
for the full architecture and update procedure.

The `sqz-mcp` build vendors `images/sqz-mcp/Cargo.lock` because its upstream
repository does not commit a lockfile. Regenerate that lockfile with
`cargo generate-lockfile` whenever `SQZ_VERSION` changes.

Image builds are manual: each image caller workflow is triggered only with
`workflow_dispatch`, so merges, pull requests, and scheduled runs do not build
or publish images. Run the workflow for the image you want to build.

`gnosis-mcp` currently means the air-gap build: its ONNX embedding model is
pre-bundled and the image is labeled with `gnosis.airgap=true`. The air-gap
variant is not represented by a tag suffix. MCP workflows publish versioned
tags only and do not publish `latest`, `latest-airgap`, or `-build-*` tags.

Each image has an individual caller workflow. The shared
`.github/workflows/build-image.yml` workflow owns checkout, metadata parsing,
GHCR authentication with `GITHUB_TOKEN`, Docker Hub authentication with
`vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN`, and dual publishing.
Image-specific smoke tests remain in the caller workflows. Gnosis candidates
are also scanned with Trivy for HIGH and CRITICAL vulnerabilities, including
unfixed findings, before any registry login or publication. Scan findings are
reported but do not block publication; external image scanning tools provide
additional security review.

The non-MCP `.github/workflows/dockerhub.yml` workflow builds the repository
root `Dockerfile` and remains outside this MCP standardization.
