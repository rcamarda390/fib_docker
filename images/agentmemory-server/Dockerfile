ARG III_VERSION=0.11.2

FROM iiidev/iii:${III_VERSION} AS iii-image

FROM node:26-slim

ARG AGENTMEMORY_VERSION=0.9.29
ARG AGENTMEMORY_IMAGE_VERSION=v1
ARG III_VERSION=0.11.2
ARG III_SDK_VERSION=0.11.2
ARG TRANSFORMERS_VERSION=4.2.0
ARG TRANSFORMERS_MODEL_REVISION=751bff37182d3f1213fa05d7196b954e230abad9
ARG TRANSFORMERS_MODEL_ID=Xenova/all-MiniLM-L6-v2

LABEL org.opencontainers.image.title="agentmemory" \
      org.opencontainers.image.version="${AGENTMEMORY_VERSION}-${AGENTMEMORY_IMAGE_VERSION}" \
      org.opencontainers.image.description="Combined AgentMemory and iii runtime with offline local embeddings" \
      agentmemory.version="${AGENTMEMORY_VERSION}" \
      agentmemory.iii-version="${III_VERSION}" \
      agentmemory.embedding-provider="local" \
      agentmemory.embedding-model="${TRANSFORMERS_MODEL_ID}" \
      agentmemory.embedding-dimensions="384" \
      agentmemory.transformers-version="${TRANSFORMERS_VERSION}" \
      agentmemory.model-revision="${TRANSFORMERS_MODEL_REVISION}"

RUN apt-get update \
 && apt-get install -y --no-install-recommends openssl ca-certificates tini gosu curl \
 && rm -rf /var/lib/apt/lists/*

COPY --from=iii-image /app/iii /usr/local/bin/iii

# Match the upstream AgentMemory deployment: install into a local prefix so
# npm overrides can pin iii-sdk to the same version as the bundled iii engine.
WORKDIR /opt/agentmemory
RUN printf '{"name":"agentmemory-deploy","version":"1.0.0","private":true,"overrides":{"iii-sdk":"%s"}}\n' "${III_SDK_VERSION}" > package.json \
 && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" "@huggingface/transformers@${TRANSFORMERS_VERSION}" --include=optional --no-fund --no-audit \
 && test "$(node -p "require('./node_modules/@huggingface/transformers/package.json').version")" = "${TRANSFORMERS_VERSION}" \
 && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory

ENV AGENTMEMORY_III_VERSION=${III_VERSION} \
    EMBEDDING_PROVIDER=local \
    AGENTMEMORY_AUTO_COMPRESS=false \
    AGENTMEMORY_INJECT_CONTEXT=false \
    GRAPH_EXTRACTION_ENABLED=false \
    CONSOLIDATION_ENABLED=false \
    TRANSFORMERS_MODEL_PATH=/opt/agentmemory/models \
    TRANSFORMERS_CACHE_DIR=/opt/agentmemory/transformers-cache \
    TRANSFORMERS_OFFLINE=1 \
    HF_HUB_OFFLINE=1 \
    NODE_OPTIONS=--import=/opt/agentmemory/transformers-offline.mjs \
    TINI_SUBREAPER=1

RUN set -eux; \
    model_dir="/opt/agentmemory/models/${TRANSFORMERS_MODEL_ID}"; \
    mkdir -p "${model_dir}/onnx" /opt/agentmemory/transformers-cache; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/config.json" \
      -o "${model_dir}/config.json"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/tokenizer.json" \
      -o "${model_dir}/tokenizer.json"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/tokenizer_config.json" \
      -o "${model_dir}/tokenizer_config.json"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/special_tokens_map.json" \
      -o "${model_dir}/special_tokens_map.json"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/vocab.txt" \
      -o "${model_dir}/vocab.txt"; \
    curl --proto '=https' --tlsv1.2 --fail --location --retry 3 --retry-all-errors \
      "https://huggingface.co/${TRANSFORMERS_MODEL_ID}/resolve/${TRANSFORMERS_MODEL_REVISION}/onnx/model_quantized.onnx" \
      -o "${model_dir}/onnx/model_quantized.onnx"; \
    printf '%s  %s\n' \
      '7135149f7cffa1a573466c6e4d8423ed73b62fd2332c575bf738a0d033f70df7' "${model_dir}/config.json" \
      'da0e79933b9ed51798a3ae27893d3c5fa4a201126cef75586296df9b4d2c62a0' "${model_dir}/tokenizer.json" \
      '9261e7d79b44c8195c1cada2b453e55b00aeb81e907a6664974b4d7776172ab3' "${model_dir}/tokenizer_config.json" \
      'b6d346be366a7d1d48332dbc9fdf3bf8960b5d879522b7799ddba59e76237ee3' "${model_dir}/special_tokens_map.json" \
      '07eced375cec144d27c900241f3e339478dec958f92fddbc551f295c992038a3' "${model_dir}/vocab.txt" \
      'afdb6f1a0e45b715d0bb9b11772f032c399babd23bfc31fed1c170afc848bdb1' "${model_dir}/onnx/model_quantized.onnx" \
      | sha256sum -c -; \
    test -s "${model_dir}/config.json"; \
    test -s "${model_dir}/tokenizer.json"; \
    test -s "${model_dir}/tokenizer_config.json"; \
    test -s "${model_dir}/onnx/model_quantized.onnx"; \
    chmod -R a-w /opt/agentmemory/models /opt/agentmemory/transformers-cache

COPY --chmod=0644 transformers-offline.mjs /opt/agentmemory/transformers-offline.mjs
COPY --chmod=0755 offline-embedding-smoke.mjs /opt/agentmemory/offline-embedding-smoke.mjs

# This is deliberately a network-disabled build step. It proves the staged
# model is sufficient before the image can be published.
RUN --network=none node /opt/agentmemory/offline-embedding-smoke.mjs

COPY --chmod=0755 entrypoint.sh /usr/local/bin/agentmemory-entrypoint.sh

EXPOSE 3111

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agentmemory-entrypoint.sh"]
