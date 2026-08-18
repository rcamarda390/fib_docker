# syntax=docker/dockerfile:1.7

ARG BIFROST_VERSION=1.6.11
ARG BIFROST_COMMIT=0a8a38c983b7b932a3f7b4e85adeac08ad99b497

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS source
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "transports/v${BIFROST_VERSION}" \
       https://github.com/maximhq/bifrost.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$BIFROST_COMMIT"

FROM node:25-alpine3.23@sha256:bdf2cca6fe3dabd014ea60163eca3f0f7015fbd5c7ee1b0e9ccb4ced6eb02ef4 AS ui-builder
WORKDIR /app
RUN apk upgrade --no-cache
COPY --from=source /src/ui/package*.json ./
RUN npm ci
COPY --from=source /src/ui/ ./
RUN npm run build-enterprise

FROM golang:1.26.5-alpine3.23@sha256:622e56dbc11a8cfe87cafa2331e9a201877271cbff918af53d3be315f3da88cc AS builder
WORKDIR /app
RUN apk upgrade --no-cache \
    && apk add --no-cache gcc musl-dev sqlite-dev binutils binutils-gold
ENV CGO_ENABLED=1 \
    GOOS=linux \
    GOWORK=off

COPY --from=source /src/transports/go.mod /src/transports/go.sum ./
RUN go mod download
COPY --from=source /src/transports/ ./
COPY --from=ui-builder /app/out ./bifrost-http/ui

ARG BIFROST_VERSION
RUN go build \
      -ldflags="-w -s -X main.Version=v${BIFROST_VERSION} -extldflags '-static'" \
      -a -trimpath \
      -tags "sqlite_static" \
      -o /app/main \
      ./bifrost-http \
    && test -f /app/main

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11
ARG BIFROST_VERSION
ARG BIFROST_COMMIT
WORKDIR /app
RUN apk upgrade --no-cache \
    && apk add --no-cache musl libgcc ca-certificates zlib

COPY --from=builder /app/main .
COPY --from=source /src/transports/docker-entrypoint.sh .

ENV APP_DIR=/app/data \
    APP_PORT=8080 \
    APP_HOST=0.0.0.0 \
    LOG_LEVEL=info \
    LOG_STYLE=json \
    GOGC="" \
    GOMEMLIMIT=""

RUN mkdir -p "$APP_DIR/logs" \
    && adduser -D -s /bin/sh appuser \
    && chown -R appuser:appuser /app \
    && chown -R appuser:0 "$APP_DIR" \
    && { [ "$APP_DIR" = "/app" ] || chmod -R g=rwX "$APP_DIR"; } \
    && chmod +x /app/docker-entrypoint.sh
USER 1000:0

VOLUME ["${APP_DIR}"]
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:${APP_PORT}/health || exit 1

LABEL org.opencontainers.image.title="bifrost-mcp" \
      org.opencontainers.image.description="Bifrost AI gateway with MCP tool support, built from source" \
      org.opencontainers.image.source="https://github.com/maximhq/bifrost" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${BIFROST_VERSION}" \
      org.opencontainers.image.revision="${BIFROST_COMMIT}"

ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/main"]
