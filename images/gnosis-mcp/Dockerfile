# syntax=docker/dockerfile:1.7
# =============================================================================
# gnosis-mcp — air-gap variant
# =============================================================================
# Installs gnosis-mcp from PyPI and bakes the ONNX embedding model
# (MongoDB/mdbr-leaf-ir, ~23 MB) into the image so no internet access is
# needed at runtime.
#
# huggingface_hub is guaranteed present:
#   gnosis-mcp[embeddings] -> tokenizers >= 0.22 -> huggingface-hub >= 0.16
#
# BUILD (internet machine):
#   docker build -f Dockerfile.airgap \
#     --build-arg GNOSIS_VERSION=0.13.3 \
#     -t gnosis-mcp:0.13.3-airgap \
#     --no-cache .
#
# PUSH to Artifactory:
#   docker tag gnosis-mcp:0.13.3-airgap <artifactory-host>/gnosis-mcp:0.13.3-airgap
#   docker push <artifactory-host>/gnosis-mcp:0.13.3-airgap
#
# INGEST (first run or after vault re-parse):
#   docker run --rm \
#     -v /path/to/markdown-vault/online-docs:/docs:ro \
#     -v gnosis-data:/data \
#     gnosis-mcp:0.13.3-airgap \
#     ingest /docs --embed --prune
#
# SERVE:
#   docker compose up -d          (see docker-compose.yaml)
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

# Install gnosis-mcp to a prefix so only app deps are copied to runtime.
# web + postgres extras are excluded — not needed for air-gap markdown ingest.
# Add reranking=false (default); enable via GNOSIS_MCP_RERANK_ENABLED if needed.
ARG GNOSIS_VERSION=0.13.3
ARG EXTRAS="embeddings"
RUN pip install --prefix=/install "gnosis-mcp[${EXTRAS}]==${GNOSIS_VERSION}"

# Pre-download the ONNX embedding model at build time.
# tokenizers (a dep of [embeddings]) pulls in huggingface_hub unconditionally,
# so it is always available in /install at this point.
#
# We set HF_HOME=/model-cache and download to that path.
# The runtime image copies /model-cache and sets HF_HUB_OFFLINE=1 so
# gnosis-mcp reads from this cache without touching the network.
#
# Excluded patterns: PyTorch / TF / Flax / Rust weights — ONNX only.
ARG EMBED_MODEL="MongoDB/mdbr-leaf-ir"
ENV HF_HOME=/model-cache

RUN set -e; \
    PYPATH=$(python3 -c \
      "import sys; print(f'/install/lib/python{sys.version_info.major}.{sys.version_info.minor}/site-packages')") \
    && echo "Using PYTHONPATH=${PYPATH}" \
    && PYTHONPATH=${PYPATH} python3 -c " \
from huggingface_hub import snapshot_download; \
print('Pre-downloading ${EMBED_MODEL} ...', flush=True); \
path = snapshot_download( \
    repo_id='${EMBED_MODEL}', \
    ignore_patterns=[ \
        '*.bin', '*.pt', '*.pth', '*.safetensors', \
        'pytorch_model*', 'tf_model*', 'flax_model*', \
        '*.msgpack', 'rust_model*', \
    ], \
); \
print(f'Cached at: {path}', flush=True); \
"

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

# libgomp1 — required by onnxruntime (OpenMP threading)
# curl     — required by HEALTHCHECK
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgomp1 \
        curl \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/gnosis --shell /bin/false gnosis

# Copy installed Python packages and pre-downloaded model from builder
COPY --from=builder /install      /usr/local
COPY --from=builder /model-cache  /model-cache

# Runtime environment
# HF_HOME must match builder's /model-cache so gnosis-mcp finds the cache.
# HF_HUB_OFFLINE=1 + TRANSFORMERS_OFFLINE=1 block all outbound HF network calls.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    GNOSIS_MCP_HOST=0.0.0.0 \
    GNOSIS_MCP_PORT=8000 \
    GNOSIS_MCP_DATABASE_URL=sqlite:////data/docs.db \
    GNOSIS_MCP_EMBED_PROVIDER=local \
    GNOSIS_MCP_ACCESS_LOG=true \
    GNOSIS_MCP_WRITABLE=false \
    HF_HOME=/model-cache \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

RUN mkdir -p /data /docs \
    && chown -R gnosis:gnosis /data /home/gnosis

USER gnosis
WORKDIR /home/gnosis

EXPOSE 8000

# /data — persistent SQLite database (mount a named volume here)
# /docs — vault online-docs directory (mount read-only)
VOLUME ["/data"]

# start-period 30s: model loads on first request, not at startup.
# If you pre-warm the model at startup, reduce to 15s.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${GNOSIS_MCP_PORT}/health" || exit 1

LABEL org.opencontainers.image.title="gnosis-mcp-airgap" \
      org.opencontainers.image.description="Self-hosted MCP docs server — air-gap variant, ONNX model pre-bundled." \
      org.opencontainers.image.source="https://github.com/nicholasglazer/gnosis-mcp" \
      org.opencontainers.image.licenses="MIT" \
      gnosis.airgap="true" \
      gnosis.embed-model="MongoDB/mdbr-leaf-ir" \
      gnosis.gnosis-version="0.13.3"

# Default: serve over HTTP (MCP at /mcp, REST at /api/*)
# Pass any gnosis-mcp CLI command as CMD to run one-offs:
#   docker run ... gnosis-mcp:0.13.3-airgap ingest /docs --embed --prune
#   docker run ... gnosis-mcp:0.13.3-airgap stats
#   docker run ... gnosis-mcp:0.13.3-airgap check
ENTRYPOINT ["gnosis-mcp"]
CMD ["serve", "--transport", "streamable-http", "--rest"]
