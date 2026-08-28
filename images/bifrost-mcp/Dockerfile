# syntax=docker/dockerfile:1.7

ARG BIFROST_VERSION=2.0.0
ARG BIFROST_COMMIT=e4a30d6041c0446603aea615bc5da340dac001b1

# Go toolchain the gateway binary is compiled with. Bifrost v2.0.0 declares
# go 1.27.0 in transports/go.mod and upstream builds with this exact toolchain.
# Xray also reads the compiler version from the binary's build info, so keep
# the toolchain pinned and verified as part of the image supply chain.
ARG GO_VERSION=1.27.0

# Module versions that clear the Xray findings against upstream v2.0.0's
# transports/go.mod:
#   x/text v0.37.0            CVE-2026-56852 (7.5), fixed in v0.39.0; v0.40.0
#                             is the version go-openapi/validate v0.26.1
#                             itself requires, so MVS lands there
#   x/net v0.55.0             CVE-2026-46600 (7.5), fixed in v0.56.0; v0.57.0
#                             is required by validate v0.26.1 the same way
#   go-git/v5 v5.19.1         CVE-2026-71556 (7.1), CVE-2026-71557 (6.3),
#                             fixed in v5.19.2
#   go-openapi/spec v0.22.3   XRAY-1032958/1032961/1032962, fixed in v0.22.7,
#                             and XRAY-1032963 (9.3), fixed in v0.22.9
#   swag/{json,yaml}utils     XRAY-1032959/1032960 against v0.25.4, fixed in
#                             v0.27.1; v0.27.3 is the version go-openapi/spec
#                             v0.22.9 itself requires, so MVS lands there
#   go-openapi/validate       XRAY-1032963 (9.3, CWE-918) and XRAY-1032962
#     v0.25.1                 (5.3, CWE-400), fixed in v0.26.1. These are the
#                             same two advisories the spec pin above answers,
#                             reported a second time against validate: it is a
#                             separate module upstream requires on its own, so
#                             raising spec left it behind at v0.25.1 and the
#                             1.6.11-v8 scan still flagged it. Pulls the rest
#                             of the go-openapi stack up with it (analysis
#                             v0.25.5, loads v0.25.0, strfmt v0.27.0,
#                             errors v0.22.8).
# Drop a pin once upstream's own go.mod requires that version or newer.
ARG GO_TEXT_VERSION=v0.40.0
ARG GO_NET_VERSION=v0.57.0
ARG GO_GIT_VERSION=v5.19.2
ARG GO_OPENAPI_SPEC_VERSION=v0.22.9
ARG GO_OPENAPI_SWAG_VERSION=v0.27.3
ARG GO_OPENAPI_VALIDATE_VERSION=v0.26.1

FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 AS source
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

FROM golang:1.27.0-alpine3.24@sha256:4c9fe60190a2a3350ddc51de80d0224b8a6698d12bdfc999fee45ea9d6c46dbc AS builder
ARG GO_VERSION
WORKDIR /app
# The digest is what actually selects the image, so confirm it still carries the
# toolchain GO_VERSION names rather than trusting the tag written beside it.
RUN go version | grep -qwF "go${GO_VERSION}" \
    && apk upgrade --no-cache \
    && apk add --no-cache gcc musl-dev sqlite-dev binutils binutils-gold
ENV CGO_ENABLED=1 \
    GOOS=linux \
    GOWORK=off \
    GOTOOLCHAIN=local

COPY --from=source /src/transports/go.mod /src/transports/go.sum ./
RUN go mod download
COPY --from=source /src/transports/ ./
COPY --from=ui-builder /app/out ./bifrost-http/ui

# Raise the flagged modules to their fix versions, then prove the resolved
# build list matches. Upstream is pinned to an exact commit and every pin below
# is an exact version, so module resolution is reproducible: a mismatch means an
# input moved and the new graph needs re-checking, not that the check is noisy.
ARG GO_TEXT_VERSION
ARG GO_NET_VERSION
ARG GO_GIT_VERSION
ARG GO_OPENAPI_SPEC_VERSION
ARG GO_OPENAPI_SWAG_VERSION
ARG GO_OPENAPI_VALIDATE_VERSION
RUN set -eu; \
    GOFLAGS=-mod=mod go get \
      "golang.org/x/text@${GO_TEXT_VERSION}" \
      "golang.org/x/net@${GO_NET_VERSION}" \
      "github.com/go-git/go-git/v5@${GO_GIT_VERSION}" \
      "github.com/go-openapi/spec@${GO_OPENAPI_SPEC_VERSION}" \
      "github.com/go-openapi/swag/jsonutils@${GO_OPENAPI_SWAG_VERSION}" \
      "github.com/go-openapi/swag/yamlutils@${GO_OPENAPI_SWAG_VERSION}" \
      "github.com/go-openapi/validate@${GO_OPENAPI_VALIDATE_VERSION}"; \
    for pin in \
      "golang.org/x/text=${GO_TEXT_VERSION}" \
      "golang.org/x/net=${GO_NET_VERSION}" \
      "github.com/go-git/go-git/v5=${GO_GIT_VERSION}" \
      "github.com/go-openapi/spec=${GO_OPENAPI_SPEC_VERSION}" \
      "github.com/go-openapi/swag/jsonutils=${GO_OPENAPI_SWAG_VERSION}" \
      "github.com/go-openapi/swag/yamlutils=${GO_OPENAPI_SWAG_VERSION}" \
      "github.com/go-openapi/validate=${GO_OPENAPI_VALIDATE_VERSION}"; \
    do \
      module="${pin%=*}"; expected="${pin##*=}"; \
      resolved="$(go list -m -f '{{.Version}}' "$module")"; \
      if test "$resolved" != "$expected"; then \
        echo "unremediated: $module resolved to '$resolved', expected $expected" >&2; \
        exit 1; \
      fi; \
      echo "remediated: $module $resolved"; \
    done

ARG BIFROST_VERSION
RUN go build \
      -ldflags="-w -s -X main.Version=v${BIFROST_VERSION} -extldflags '-static'" \
      -a -trimpath \
      -tags "sqlite_static" \
      -o /app/main \
      ./bifrost-http \
    && test -f /app/main
# The compiler stamped into the binary is the component Xray scans, so fail here
# if the build somehow ran on a toolchain other than the pinned one.
RUN go version -m /app/main | grep -qwF "go${GO_VERSION}"

FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40
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
