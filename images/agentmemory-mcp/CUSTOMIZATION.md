# Customization

## Image metadata

Edit the appropriate `image.yaml` file before building:

- `../agentmemory/image.yaml`
- `../iii-engine/image.yaml`

Set `upstream_version` when changing the upstream release. Published image
builds increment and commit `revision` automatically; pull request validation
builds do not consume revisions. Additional Dockerfile arguments belong in the
`build_args` map.

The npm dependency graph is reviewed in `package-lock.json`; update
`package.json` and regenerate the lockfile before changing application
versions. The Dockerfile uses `npm ci` and does not resolve a fresh graph
during image builds.

The Gnosis image uses a hash-pinned Python lockfile generated from
`images/gnosis-mcp/requirements.in`. Regenerate and review
`requirements.lock` when updating its upstream version or extras.

Images are tagged as `<upstream-version>-v<revision>` and published to both
GHCR and Docker Hub. The Docker Hub username is the repository variable
`DOCKERHUB_USERNAME`; the access token is the `DOCKERHUB_TOKEN` repository
secret.

## Offline operation

The agentmemory image pre-caches its transformer model and sets
`TRANSFORMERS_OFFLINE=1` and `HF_HUB_OFFLINE=1`. The iii-engine image uses the
tracked release binary and does not perform an image-build revision update.

`gnosis-mcp` is built separately from `../gnosis-mcp`. All published
`gnosis-mcp` images are currently the air-gap variant with its ONNX model
pre-bundled. That meaning is recorded in image labels, not in a tag suffix.

See [`docs/MCP_BUILD_METHODOLOGY.md`](../../docs/MCP_BUILD_METHODOLOGY.md) for
the complete workflow and registry policy.
