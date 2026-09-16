# syntax=docker/dockerfile:1.7

ARG DOCKER_SOCKET_PROXY_VERSION=0.5.0
ARG DOCKER_SOCKET_PROXY_DIGEST=sha256:1f5038b54f06c3e18422902cf00ba21803d1c97805aae032e5e6673d532d3459

FROM tecnativa/docker-socket-proxy:v${DOCKER_SOCKET_PROXY_VERSION}@${DOCKER_SOCKET_PROXY_DIGEST}

ARG DOCKER_SOCKET_PROXY_VERSION
ARG DOCKER_SOCKET_PROXY_DIGEST

# Runtime permissions from the deployment configuration. The upstream image
# keeps harmless API sections enabled by default (PING and VERSION).
ENV CONTAINERS=1 \
    EXEC=1 \
    POST=1 \
    IMAGES=0 \
    NETWORKS=0 \
    VOLUMES=0 \
    BUILD=0 \
    COMMIT=0 \
    CONFIGS=0 \
    DISTRIBUTION=0 \
    PLUGINS=0 \
    SERVICES=0 \
    SESSION=0 \
    SWARM=0 \
    SYSTEM=0 \
    TASKS=0 \
    NODES=0 \
    INFO=0 \
    ALLOW_START=0 \
    ALLOW_STOP=0 \
    ALLOW_RESTARTS=0

LABEL org.opencontainers.image.title="docker-socket-proxy" \
      org.opencontainers.image.description="Docker socket proxy with restricted API access" \
      org.opencontainers.image.source="https://github.com/Tecnativa/docker-socket-proxy" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${DOCKER_SOCKET_PROXY_VERSION}" \
      org.opencontainers.image.revision="${DOCKER_SOCKET_PROXY_DIGEST}"
