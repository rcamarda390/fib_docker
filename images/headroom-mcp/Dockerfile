# syntax=docker/dockerfile:1.7

ARG HEADROOM_VERSION=0.34.0
ARG HEADROOM_COMMIT=9fd5ae3d530b5d9eb9e9127e413235a5a3b2faf6
ARG PYTHON_VERSION=3.13

FROM alpine:3.23.4 AS source
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "v${HEADROOM_VERSION}" \
       https://github.com/headroomlabs-ai/headroom.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$HEADROOM_COMMIT"

FROM python:${PYTHON_VERSION}-slim AS builder
ARG HEADROOM_VERSION
ARG PYTHON_VERSION

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:${PATH} \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       build-essential g++ curl ca-certificates patchelf \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir "uv==0.11.18"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --no-modify-path --profile minimal \
        -c rustfmt -c clippy --default-toolchain 1.95.0

WORKDIR /build
COPY --from=source /src/pyproject.toml /src/uv.lock /src/README.md ./
COPY --from=source /src/Cargo.toml /src/Cargo.lock /src/rust-toolchain.toml ./
COPY --from=source /src/crates/ crates/
COPY --from=source /src/headroom/ headroom/

RUN uv pip install --system ".[mcp]"
RUN cd /tmp && python -c \
    "from headroom._core import DiffCompressor, SmartCrusher; \
     print(f'Headroom Rust core OK: {DiffCompressor.__name__}, {SmartCrusher.__name__}')"
RUN test "$(python -c 'import importlib.metadata; print(importlib.metadata.version("headroom-ai"))')" = "$HEADROOM_VERSION"

FROM python:${PYTHON_VERSION}-slim AS runtime
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT

ENV HEADROOM_HOST=0.0.0.0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd --system --create-home --home-dir /home/headroom \
      --shell /usr/sbin/nologin headroom \
    && mkdir -p /home/headroom/.headroom \
    && chown -R headroom:headroom /home/headroom
COPY --from=builder /usr/local/lib/python${PYTHON_VERSION}/site-packages \
    /usr/local/lib/python${PYTHON_VERSION}/site-packages
COPY --from=builder /usr/local/bin/headroom /usr/local/bin/headroom
COPY mcp-smoke.py /usr/local/bin/mcp-smoke.py
COPY entrypoint.sh /usr/local/bin/headroom-entrypoint
RUN chmod +x /usr/local/bin/headroom-entrypoint

USER headroom
WORKDIR /home/headroom
VOLUME ["/home/headroom/.headroom"]

LABEL org.opencontainers.image.title="headroom-mcp" \
      org.opencontainers.image.description="Headroom MCP server for context optimization" \
      org.opencontainers.image.source="https://github.com/headroomlabs-ai/headroom" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${HEADROOM_VERSION}" \
      org.opencontainers.image.revision="${HEADROOM_COMMIT}"

ENTRYPOINT ["headroom-entrypoint"]
