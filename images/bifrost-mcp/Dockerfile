# syntax=docker/dockerfile:1.7

ARG BIFROST_VERSION=1.6.7
FROM maximhq/bifrost:v${BIFROST_VERSION}

ARG BIFROST_VERSION

LABEL org.opencontainers.image.title="bifrost-mcp" \
      org.opencontainers.image.description="Bifrost AI gateway with MCP tool support" \
      org.opencontainers.image.source="https://github.com/maximhq/bifrost" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${BIFROST_VERSION}"

ENTRYPOINT ["/app/main"]
CMD ["-app-dir", "/app/data", "-port", "8080", "-host", "0.0.0.0"]
