# syntax=docker/dockerfile:1.7

ARG BIFROST_VERSION=2.0.0-prerelease2
ARG BIFROST_COMMIT=4a31f776fbe38c7177dea5034f639852d0c1342e
ARG GO_OPENAPI_VALIDATE_VERSION=v0.26.1

FROM alpine:3.23.5@sha256:1beb0dc0a51de7ff38e3b5274078a2e0b81113ba5c7535e1a03d5913a5edbda3 AS source
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "transports/v${BIFROST_VERSION}" \
       https://github.com/maximhq/bifrost.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$BIFROST_COMMIT"

FROM node:25-alpine3.23@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS ui-builder
WORKDIR /app
COPY --from=source /src/ui/package*.json ./
RUN npm ci
COPY --from=source /src/ui/ ./
RUN npm run build-enterprise

FROM golang:1.26.4-alpine3.23@sha256:18b460dd17542c2ba43299a633cf6ebfc1115101509531471d7cfce1019af083 AS builder
WORKDIR /build
RUN apk add --no-cache gcc musl-dev sqlite-dev binutils binutils-gold
ENV CGO_ENABLED=1 GOOS=linux

COPY --from=source /src/core/ ./core/
COPY --from=source /src/framework/ ./framework/
COPY --from=source /src/plugins/ ./plugins/
COPY --from=source /src/transports/ ./transports/
RUN go work init \
    && go work use ./core ./framework ./plugins/compat ./plugins/governance \
       ./plugins/jsonparser ./plugins/logging ./plugins/maxim ./plugins/mocker \
       ./plugins/otel ./plugins/prompts ./plugins/semanticcache \
       ./plugins/telemetry ./transports

# Keep the indirect validator dependency fixed across every workspace module.
ARG GO_OPENAPI_VALIDATE_VERSION
RUN set -eux; \
    for m in core framework plugins/compat plugins/governance plugins/jsonparser \
             plugins/logging plugins/maxim plugins/mocker plugins/otel plugins/prompts \
             plugins/semanticcache plugins/telemetry transports; do \
      if grep -q 'github.com/go-openapi/validate' "$m/go.mod"; then \
        (cd "$m" && GOWORK=off GOFLAGS=-mod=mod \
          go get "github.com/go-openapi/validate@${GO_OPENAPI_VALIDATE_VERSION}"); \
      fi; \
    done; \
    go work sync

RUN set -eux; \
    cd /build/transports; \
    go list -m -f '{{.Path}} {{.Version}}' all \
      | grep '^github.com/go-openapi/validate ' | tee /tmp/validate-version; \
    grep -Fxq "github.com/go-openapi/validate ${GO_OPENAPI_VALIDATE_VERSION}" /tmp/validate-version

COPY --from=ui-builder /app/out ./transports/bifrost-http/ui

ARG BIFROST_VERSION
RUN cd /build/transports \
    && go build -ldflags="-w -s -X main.Version=v${BIFROST_VERSION} -extldflags '-static'" \
       -a -trimpath -tags sqlite_static -o /app/main ./bifrost-http \
    && test -f /app/main

FROM alpine:3.23.5@sha256:1beb0dc0a51de7ff38e3b5274078a2e0b81113ba5c7535e1a03d5913a5edbda3
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
WORKDIR /app
ENV APP_DIR=/app/data \
    APP_PORT=8080 \
    APP_HOST=0.0.0.0 \
    LOG_LEVEL=info \
    LOG_STYLE=json
RUN apk add --no-cache musl libgcc ca-certificates zlib=1.3.2-r0 \
    && adduser -D -s /bin/sh appuser
COPY --from=builder /app/main .
COPY --from=source /src/transports/docker-entrypoint.sh .
RUN mkdir -p /app/data/logs \
    && chown -R appuser:appuser /app \
    && chmod +x /app/docker-entrypoint.sh
USER appuser
VOLUME ["/app/data"]
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1

LABEL org.opencontainers.image.title="bifrost-mcp" \
      org.opencontainers.image.description="Bifrost AI gateway with MCP tool support, built from source" \
      org.opencontainers.image.source="https://github.com/maximhq/bifrost" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${BIFROST_VERSION}" \
      org.opencontainers.image.revision="${BIFROST_COMMIT}"

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/main"]
