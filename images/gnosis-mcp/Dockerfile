# syntax=docker/dockerfile:1.7
# =============================================================================
# gnosis-mcp — air-gap variant (v3)
# =============================================================================
# local_embed.py downloads exactly three files from HuggingFace via stdlib
# urllib. Cache path: XDG_DATA_HOME / safe_name where safe_name is
# model_id.replace("/", "--"). We download those files directly with curl
# during build — no huggingface_hub, no warmup ingest needed.
#
# Files downloaded:
#   tokenizer.json
#   tokenizer_config.json
#   onnx/model_quantized.onnx  (falls back to onnx/model.onnx)
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
    && apt-get install -y --no-install-recommends build-essential curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG GNOSIS_VERSION=0.13.3
ARG EXTRAS="embeddings"
RUN pip install --prefix=/install "gnosis-mcp[${EXTRAS}]==${GNOSIS_VERSION}"

# Download exactly the files local_embed.py needs.
# safe_name = model_id.replace("/", "--") = MongoDB--mdbr-leaf-ir
# Tries model_quantized.onnx first, falls back to model.onnx (mirrors _ONNX_CANDIDATES).
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
    && apt-get install -y --no-install-recommends libgomp1 curl \
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
