# LiteLLM AI Gateway

Builds LiteLLM v1.91.0 from the exact upstream commit recorded in
`image.yaml`. The image runs the OpenAI-compatible proxy on port 4000 as an
unprivileged user.

Published images use immutable tags:

- `ghcr.io/rcamarda390/litellm:1.91.0-vN`
- `docker.io/rcamarda390/litellm:1.91.0-vN`

The manual `Build and publish LiteLLM image` workflow calculates the next
revision from successfully published Docker Hub tags, smoke-tests the health
endpoint, scans HIGH/CRITICAL findings, and then publishes to both registries.

Runtime credentials and configuration must be supplied through environment
variables or mounted files. Do not bake AWS credentials into the image.
