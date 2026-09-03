# syntax=docker/dockerfile:1.7

ARG ARCHIFY_VERSION=2.16.0
ARG ARCHIFY_COMMIT=c826e6c3a7abad19c0f3cd1ca57207d54b1ad8de

FROM alpine:3.23.5 AS source
ARG ARCHIFY_VERSION
ARG ARCHIFY_COMMIT

RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "v${ARCHIFY_VERSION}" \
       https://github.com/tt-a1i/archify.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$ARCHIFY_COMMIT" \
    && test "$(sed -nE 's/^[[:space:]]*\"version\":[[:space:]]*\"([^\"]+)\",?$/\1/p' /src/archify/package.json | head -1)" = "$ARCHIFY_VERSION"

FROM node:22-alpine
ARG ARCHIFY_VERSION
ARG ARCHIFY_COMMIT

# Chromium enables Archify's visual-check command inside the image. All skill,
# renderer, schema, and example assets are copied in at build time so normal
# operation does not need a package registry or the upstream repository.
RUN apk upgrade --no-cache \
    && apk add --no-cache chromium \
    && test -x /usr/bin/chromium-browser

COPY --from=source --chown=node:node /src/archify /opt/archify

RUN ln -s /opt/archify/bin/archify.mjs /usr/local/bin/archify \
    && node /opt/archify/bin/archify.mjs doctor \
    && node /opt/archify/bin/archify.mjs validate architecture \
       /opt/archify/examples/web-app.architecture.json --quality showcase --json \
    && mkdir -p /workspace \
    && chown node:node /workspace

ENV ARCHIFY_CHROME=/usr/bin/chromium-browser \
    ARCHIFY_CHROME_NO_SANDBOX=1 \
    ARCHIFY_UPDATE_CHECK_DISABLED=1

WORKDIR /workspace
USER node

LABEL org.opencontainers.image.title="archify" \
      org.opencontainers.image.description="Verifiable architecture and workflow diagram CLI and agent skill" \
      org.opencontainers.image.source="https://github.com/tt-a1i/archify" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ARCHIFY_VERSION}" \
      org.opencontainers.image.revision="${ARCHIFY_COMMIT}"

ENTRYPOINT ["node", "/opt/archify/bin/archify.mjs"]
CMD ["--help"]
