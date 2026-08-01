# syntax=docker/dockerfile:1.7
# =============================================================================
# gnosis-mcp — air-gap variant (v9)
# =============================================================================
# Patch: gnosis-mcp 0.13.3 rest.py does not wire session_manager.run() into
# the Starlette lifespan when mounting StreamableHTTP alongside REST API.
# This causes RuntimeError: Task group is not initialized on every /mcp request.
# Fix: inject a combined lifespan that runs both REST backend AND session_manager.
# Security: Python bumped to 3.13 (CVE-2026-6100); apt-get upgrade applied in
# both stages to patch perl-base (CVE-2026-42496 +4), libc-bin (CVE-2026-5450),
# curl (CVE-2026-8927/8926/9079), and libcurl4t64 (CVE-2026-11856/8924/10536).
# =============================================================================

ARG PYTHON_VERSION=3.13

# ---------------------------------------------------------------------------
# Stage 1 — builder
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS builder

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONDONTWRITEBYTECODE=1

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends build-essential curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG GNOSIS_VERSION=0.13.3
ARG EXTRAS="embeddings"
COPY requirements.lock /build/requirements.lock
RUN test "$EXTRAS" = "embeddings" \
    && grep -q "^gnosis-mcp==${GNOSIS_VERSION} " /build/requirements.lock \
    && pip install --require-hashes --prefix=/install -r /build/requirements.lock

# Patch rest.py — replace the single-lifespan Starlette construction with a
# combined lifespan that also runs session_manager for StreamableHTTP.
COPY patch_rest.py /build/patch_rest.py
RUN python3 /build/patch_rest.py

# Download exactly the files local_embed.py needs.
ARG EMBED_MODEL="MongoDB/mdbr-leaf-ir"
ENV XDG_DATA_HOME=/gnosis-model-cache

RUN set -e; \
    BASE="https://huggingface.co/${EMBED_MODEL}/resolve/main"; \
    DIR="/gnosis-model-cache/gnosis-mcp/models/MongoDB--mdbr-leaf-ir"; \
    mkdir -p "${DIR}/onnx"; \
    curl -fsSL "${BASE}/tokenizer.json"           -o "${DIR}/tokenizer.json"; \
    curl -fsSL "${BASE}/tokenizer_config.json"    -o "${DIR}/tokenizer_config.json"; \
    curl -fsSL "${BASE}/special_tokens_map.json"  -o "${DIR}/special_tokens_map.json"; \
    if curl -fsSL "${BASE}/onnx/model_quantized.onnx" -o "${DIR}/onnx/model_quantized.onnx"; then \
        echo "Downloaded model_quantized.onnx"; \
        curl -fsSL "${BASE}/onnx/model_quantized.onnx_data" -o "${DIR}/onnx/model_quantized.onnx_data" 2>/dev/null || echo "No onnx_data sidecar (ok)"; \
    else \
        curl -fsSL "${BASE}/onnx/model.onnx" -o "${DIR}/onnx/model.onnx"; \
        curl -fsSL "${BASE}/onnx/model.onnx_data" -o "${DIR}/onnx/model.onnx_data" 2>/dev/null || echo "No onnx_data sidecar (ok)"; \
        echo "Downloaded model.onnx (fallback)"; \
    fi; \
    echo "Model cache:"; \
    find /gnosis-model-cache -type f -ls

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM python:${PYTHON_VERSION}-slim AS runtime

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends libgomp1 \
    && apt-get purge -y --auto-remove --allow-remove-essential perl-base perl-modules-5.40 \
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
    && chown -R gnosis:gnosis /data /home/gnosis /gnosis-model-cache

USER gnosis
WORKDIR /home/gnosis

EXPOSE 8000
VOLUME ["/data"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:%s/health' % __import__('os').environ['GNOSIS_MCP_PORT'])" || exit 1

ARG GNOSIS_VERSION=0.13.3
ARG EMBED_MODEL="MongoDB/mdbr-leaf-ir"
LABEL org.opencontainers.image.title="gnosis-mcp" \
      org.opencontainers.image.description="Self-hosted MCP docs server — air-gap variant, ONNX model pre-bundled." \
      org.opencontainers.image.source="https://github.com/nicholasglazer/gnosis-mcp" \
      org.opencontainers.image.licenses="MIT" \
      gnosis.airgap="true" \
      gnosis.embed-model="${EMBED_MODEL}" \
      gnosis.gnosis-version="${GNOSIS_VERSION}" \
      gnosis.patch="rest.py-combined-lifespan" \
      gnosis.image-version="v9"

ENTRYPOINT ["gnosis-mcp"]
CMD ["serve", "--transport", "streamable-http", "--rest"]
