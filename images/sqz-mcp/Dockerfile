# syntax=docker/dockerfile:1.7

ARG SQZ_VERSION=1.3.0
ARG SQZ_COMMIT=d024b6b6bec152dfa7a63e2316054b1bb33a8110

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e688dd4a5019afde11 AS source
ARG SQZ_VERSION
ARG SQZ_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "v${SQZ_VERSION}" \
       https://github.com/ojuschugh1/sqz.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$SQZ_COMMIT"

FROM rust:1.82-alpine AS builder
WORKDIR /build
RUN apk add --no-cache musl-dev
COPY --from=source /src/ .
RUN cargo build --release --locked --package sqz-mcp \
    && test -f target/release/sqz-mcp \
    && mkdir -p /app \
    && cp target/release/sqz-mcp /app/sqz-mcp

FROM scratch
ARG SQZ_VERSION
ARG SQZ_COMMIT
WORKDIR /app
COPY --from=builder /app/sqz-mcp /app/sqz-mcp

LABEL org.opencontainers.image.title="sqz-mcp" \
      org.opencontainers.image.description="MCP server for sqz context compression, built from source" \
      org.opencontainers.image.source="https://github.com/ojuschugh1/sqz" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${SQZ_VERSION}" \
      org.opencontainers.image.revision="${SQZ_COMMIT}"

ENTRYPOINT ["/app/sqz-mcp"]
