# syntax=docker/dockerfile:1.7
# =============================================================================
# gnosis-mcp — air-gap variant (v2)
# =============================================================================
# Model pre-warm strategy:
#   gnosis-mcp's local_embed.py uses its OWN download code (urllib direct)
#   controlled by XDG_DATA_HOME — it does NOT use HuggingFace Hub cache.
#   We trigger gnosis-mcp's own ingest --embed during the build stage so it
#   downloads the model to XDG_DATA_HOME=/gnosis-model-cache. That directory
#   is copied to runtime and XDG_DATA_HOME is kept set, so the model is found
#   without any network access at runtime.
# =============================================================================

ARG PYTHON_VERSION=3.12

# ---------------------------------------------------------------------------
# Stage 1 — builder
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG GNOSIS_VERSION=0.13.3
ARG EXTRAS="embeddings"
RUN pip install --prefix=/install "gnosis-mcp[${EXTRAS}]==${GNOSIS_VERSION}"

# Pre-warm gnosis-mcp's own model cache by running a real ingest --embed.
# XDG_DATA_HOME controls where local_embed.py stores the ONNX model files.
# Builder has internet — model downloads here, never at runtime.
ENV XDG_DATA_HOME=/gnosis-model-cache

RUN set -e; \
    PYPATH=$(python3 -c "import sys; print(f'/install/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages')"); \
    mkdir -p /tmp/warmup-docs; \
    echo '# Warmup' > /tmp/warmup-docs/warmup.md; \
    PYTHONPATH=$PYPATH \
    XDG_DATA_HOME=/gnosis-model-cache \
    GNOSIS_MCP_DATABASE_URL=sqlite:////tmp/warmup.db \
    GNOSIS_MCP_EMBED_PROVIDER=local \
    /install/bin/gnosis-mcp init-db; \
    PYTHONPATH=$PYPATH \
    XDG_DATA_HOME=/gnosis-model-cache \
    GNOSIS_MCP_DATABASE_URL=sqlite:////tmp/warmup.db \
    GNOSIS_MCP_EMBED_PROVIDER=local \
    /install/bin/gnosis-mcp ingest /tmp/warmup-docs --embed; \
    echo "Model cache contents:"; \
    find /gnosis-model-cache -type f; \
    rm -rf /tmp/warmup-docs /tmp/warmup.db

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgomp1 \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/gnosis --shell /bin/false gnosis

COPY --from=builder /install             /usr/local
COPY --from=builder /gnosis-model-cache  /gnosis-model-cache

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GNOSIS_MCP_HOST=0.0.0.0 \
    GNOSIS_MCP_PORT=8000 \
    GNOSIS_MCP_DATABASE_URL=sqlite:////data/docs.db \
    GNOSIS_MCP_EMBED_PROVIDER=local \
    GNOSIS_MCP_ACCESS_LOG=true \
    GNOSIS_MCP_WRITABLE=false \
    XDG_DATA_HOME=/gnosis-model-cache

RUN mkdir -p /data /docs \
    && chown -R gnosis:gnosis /data /home/gnosis

USER gnosis
WORKDIR /home/gnosis

EXPOSE 8000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${GNOSIS_MCP_PORT}/health" || exit 1

LABEL org.opencontainers.image.title="gnosis-mcp-airgap" \
      org.opencontainers.image.description="Self-hosted MCP docs server — air-gap variant, ONNX model pre-bundled." \
      org.opencontainers.image.source="https://github.com/nicholasglazer/gnosis-mcp" \
      org.opencontainers.image.licenses="MIT" \
      gnosis.airgap="true" \
      gnosis.embed-model="MongoDB/mdbr-leaf-ir" \
      gnosis.gnosis-version="0.13.3"

ENTRYPOINT ["gnosis-mcp"]
CMD ["serve", "--transport", "streamable-http", "--rest"]
