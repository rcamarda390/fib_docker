# Registry publishing

MCP images are published to both registries using the shared
`.github/workflows/build-image.yml` workflow:

- `ghcr.io/rcamarda390/<image>:<upstream-version>-v<revision>`
- `docker.io/rcamarda390/<image>:<upstream-version>-v<revision>`

Configure `DOCKERHUB_USERNAME` as a repository variable and
`DOCKERHUB_TOKEN` as a repository secret. GHCR uses the workflow's
`GITHUB_TOKEN`.

Artifactory can cache the Docker Hub images for air-gapped deployment. The
`gnosis-mcp` image is itself the air-gap build; its tag does not include an
`airgap` suffix.
