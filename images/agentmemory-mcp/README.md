# MCP images

This directory contains the Dockerfiles for the `agentmemory` and
`iii-engine` MCP support images. Metadata and revisions are maintained in:

- [`../agentmemory/image.yaml`](../agentmemory/image.yaml)
- [`../iii-engine/image.yaml`](../iii-engine/image.yaml)

Images use the tag format `<upstream-version>-v<revision>`, for example
`agentmemory:0.9.28-v4` and `iii-engine:0.22.0-v9`. Each versioned tag is
published to both GHCR and Docker Hub; no floating tags are published.

The builds are driven by the individual workflows
`build-agentmemory.yml` and `build-iii-engine.yml`, which call the shared
`build-image.yml` workflow. Smoke tests stay in those individual callers.
For a coordinated manual build of both images, use
`build-agentmemory-both.yml`; its `push_ghcr` and `push_dockerhub` inputs
independently control publication, and leaving both unchecked only validates
the image candidates.

`gnosis-mcp` is maintained separately in [`../gnosis-mcp`](../gnosis-mcp). It
is currently the air-gap build, with its model pre-bundled and its air-gap
meaning preserved through image labels rather than a tag suffix. See
[`docs/MCP_BUILD_METHODOLOGY.md`](../../docs/MCP_BUILD_METHODOLOGY.md).
