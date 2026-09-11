# syntax=docker/dockerfile:1.7

ARG PYTHON_IMAGE=python:3.13-slim-bookworm
ARG LITELLM_VERSION=1.91.0
ARG LITELLM_COMMIT=0519dbf25b290dd3a646bf40dc93d40ae36901aa

FROM ${PYTHON_IMAGE} AS builder

ARG LITELLM_VERSION
ARG LITELLM_COMMIT

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends build-essential git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --filter=blob:none --no-checkout https://github.com/BerriAI/litellm.git . \
    && git checkout --detach "${LITELLM_COMMIT}" \
    && test "$(git rev-parse HEAD)" = "${LITELLM_COMMIT}" \
    && test "$(python -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')" = "${LITELLM_VERSION}"

RUN python -m venv /opt/litellm \
    && /opt/litellm/bin/pip install --no-cache-dir --upgrade pip \
    && /opt/litellm/bin/pip install --no-cache-dir '.[proxy]' \
    && /opt/litellm/bin/python -c 'import litellm; import litellm.proxy.proxy_server'

FROM ${PYTHON_IMAGE} AS runtime

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends ca-certificates curl libsndfile1 \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 litellm

COPY --from=builder /opt/litellm /opt/litellm

ENV PATH="/opt/litellm/bin:${PATH}" \
    LITELLM_PORT=4000

WORKDIR /app
USER 10001:10001

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl --fail --silent http://127.0.0.1:4000/health/liveliness >/dev/null || exit 1

LABEL org.opencontainers.image.title="litellm" \
      org.opencontainers.image.description="LiteLLM AI Gateway built from pinned upstream source" \
      org.opencontainers.image.source="https://github.com/BerriAI/litellm" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${LITELLM_VERSION}" \
      org.opencontainers.image.revision="${LITELLM_COMMIT}"

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
