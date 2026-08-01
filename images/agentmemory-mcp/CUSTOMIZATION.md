# Customization

## Image metadata

Edit the appropriate `image.yaml` file before building:

- `../agentmemory/image.yaml`
- `../iii-engine/image.yaml`

Set `upstream_version` and increment `revision` manually for each published
image revision. The workflows only read these values; they never modify
tracked files or push commits back to the repository. Additional Dockerfile
arguments belong in the `build_args` map.

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
