# syntax=docker/dockerfile:1.7

ARG HEADROOM_VERSION=0.35.0
ARG HEADROOM_COMMIT=93f2d7a2da4d3b6c88f31bad164ae299cf042104
ARG PYTHON_VERSION=3.13
ARG PIP_VERSION=26.2.1
ARG RUSTUP_VERSION=1.28.2

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS source
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "v${HEADROOM_VERSION}" \
       https://github.com/headroomlabs-ai/headroom.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$HEADROOM_COMMIT"

FROM python:${PYTHON_VERSION}-slim-bookworm AS builder
ARG HEADROOM_VERSION
ARG PYTHON_VERSION
ARG PIP_VERSION
ARG RUSTUP_VERSION

ENV CARGO_HOME=/usr/local/cargo \
    RUSTUP_HOME=/usr/local/rustup \
    PATH=/usr/local/cargo/bin:${PATH} \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
       build-essential g++ curl ca-certificates patchelf \
    && rm -rf /var/lib/apt/lists/*

RUN python -m pip install --no-cache-dir \
      "pip==${PIP_VERSION}" \
      "uv==0.11.18"
# Checksums come from the matching rustup-init.sha256 file in the Rust release
# archive.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) rust_arch=x86_64-unknown-linux-gnu; rust_sha=20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c ;; \
      arm64) rust_arch=aarch64-unknown-linux-gnu; rust_sha=e3853c5a252fca15252d07cb23a1bdd9377a8c6f3efa01531109281ae47f841c ;; \
      *) echo "Unsupported architecture for rustup installer" >&2; exit 1 ;; \
    esac; \
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
      "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/${rust_arch}/rustup-init" \
      --output /tmp/rustup-init; \
    echo "${rust_sha}  /tmp/rustup-init" | sha256sum --check --status; \
    chmod +x /tmp/rustup-init; \
    /tmp/rustup-init -y --no-modify-path --profile minimal \
      -c rustfmt -c clippy --default-toolchain 1.95.0; \
    rm /tmp/rustup-init

WORKDIR /build
COPY --from=source /src/pyproject.toml /src/uv.lock /src/README.md ./
COPY --from=source /src/Cargo.toml /src/Cargo.lock /src/rust-toolchain.toml ./
COPY --from=source /src/crates/ crates/
COPY --from=source /src/headroom/ headroom/

# The pinned upstream release can contain a lockfile that uv considers stale
# when evaluated against the release metadata. Use the checked-in resolution
# without attempting to rewrite it during the image build.
RUN uv sync --frozen --extra mcp --no-dev --no-editable
RUN cd /tmp && PATH="/opt/venv/bin:${PATH}" python -c \
    "from headroom._core import DiffCompressor, SmartCrusher; \
     print(f'Headroom Rust core OK: {DiffCompressor.__name__}, {SmartCrusher.__name__}')"
RUN test "$(PATH="/opt/venv/bin:${PATH}" python -c 'import importlib.metadata; print(importlib.metadata.version("headroom-ai"))')" = "$HEADROOM_VERSION"

FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
ARG PYTHON_VERSION
ARG PIP_VERSION

ENV HEADROOM_HOST=0.0.0.0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/opt/venv/bin:${PATH}

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/headroom \
      --shell /usr/sbin/nologin headroom \
    && mkdir -p /home/headroom/.headroom \
    && chown -R headroom:headroom /home/headroom
# Keep the base interpreter's pip out of the scanner's vulnerable range even
# though the application itself runs from the locked virtual environment.
RUN python -m pip install --no-cache-dir --upgrade "pip==${PIP_VERSION}" \
    && rm -rf /root/.cache
# Every perl-base CVE the scanner reports against bookworm is published with no
# fixed version, so `apt-get upgrade` above cannot clear them. Nothing in this
# image invokes perl: the entrypoint is dash and the payload is Python plus a
# Rust extension module. Drop the package outright rather than carry unfixable
# findings. dpkg is used instead of `apt-get purge --auto-remove` because
# perl-base is Essential and apt would cascade into debconf; no further apt
# operations run after this layer, so the unsatisfied dependency is inert. The
# final check fails the build if perl somehow survives, so this can never
# silently degrade into a no-op.
RUN dpkg --purge --force-depends --force-remove-essential perl-base \
    && ! command -v perl
COPY --from=builder /opt/venv /opt/venv
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
