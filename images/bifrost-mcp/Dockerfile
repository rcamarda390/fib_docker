# syntax=docker/dockerfile:1.7

ARG BIFROST_VERSION=1.6.11
ARG BIFROST_COMMIT=0a8a38c983b7b932a3f7b4e85adeac08ad99b497
ARG GO_OPENAPI_VALIDATE_VERSION=v0.27.0
ARG GO_GIT_VERSION=v5.12.0
ARG GRPC_VERSION=v1.68.0

FROM alpine:3.21 AS source
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "transports/v${BIFROST_VERSION}" \
       https://github.com/maximhq/bifrost.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$BIFROST_COMMIT"

FROM node:22-alpine3.21 AS ui-builder
WORKDIR /app
COPY --from=source /src/ui/package*.json ./
RUN npm ci
COPY --from=source /src/ui/ ./
RUN npm run build-enterprise

FROM golang:1.23.4-alpine3.21 AS builder
ARG GO_GIT_VERSION
ARG GRPC_VERSION
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
    (cd transports && GOWORK=off GOFLAGS=-mod=mod \
      go get "github.com/go-git/go-git/v5@${GO_GIT_VERSION}" \
        "google.golang.org/grpc@${GRPC_VERSION}"); \
    go work sync

RUN set -eux; \
    cd /build/transports; \
    go list -m -f '{{.Path}} {{.Version}}' all \
      | grep '^github.com/go-openapi/validate ' | tee /tmp/validate-version; \
    grep -Fxq "github.com/go-openapi/validate ${GO_OPENAPI_VALIDATE_VERSION}" /tmp/validate-version

RUN set -eux; \
    cd /build/transports; \
    go list -m -f '{{.Path}} {{.Version}}' all \
      | grep -E '^(github.com/go-git/go-git/v5|google.golang.org/grpc) ' \
      | tee /tmp/bifrost-remediated-versions; \
    grep -Fxq "github.com/go-git/go-git/v5 ${GO_GIT_VERSION}" /tmp/bifrost-remediated-versions; \
    grep -Fxq "google.golang.org/grpc ${GRPC_VERSION}" /tmp/bifrost-remediated-versions

COPY --from=ui-builder /app/out ./transports/bifrost-http/ui

ARG BIFROST_VERSION
RUN cd /build/transports \
    && go build -ldflags="-w -s -X main.Version=v${BIFROST_VERSION} -extldflags '-static'" \
       -a -trimpath -tags sqlite_static -o /app/main ./bifrost-http \
    && test -f /app/main

FROM alpine:3.21
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
WORKDIR /app
ENV APP_DIR=/app/data \
    APP_PORT=8080 \
    APP_HOST=0.0.0.0 \
    LOG_LEVEL=info \
    LOG_STYLE=json
RUN apk add --no-cache musl libgcc ca-certificates zlib \
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
