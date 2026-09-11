# syntax=docker/dockerfile:1.7

ARG WOLFI_IMAGE=cgr.dev/chainguard/wolfi-base@sha256:42df77a9974d6ec8b17a5ee8bc23b532600a44d705acef2409e0933c1251b45f
ARG UV_IMAGE=ghcr.io/astral-sh/uv:0.11.7@sha256:240fb85ab0f263ef12f492d8476aa3a2e4e1e333f7d67fbdd923d00a506a516a
ARG LITELLM_VERSION=1.94.3
ARG LITELLM_COMMIT=397859f6722909451ae573229aa9daef7ed960c9

FROM ${UV_IMAGE} AS uvbin

FROM ${WOLFI_IMAGE} AS builder

ARG LITELLM_VERSION
ARG LITELLM_COMMIT

RUN apk upgrade --available --no-cache \
    && apk add --no-cache --upgrade glibc \
    && apk add --no-cache bash gcc git python3 python3-dev rust openssl-dev libsndfile

COPY --from=uvbin /uv /usr/local/bin/uv

WORKDIR /src
RUN git clone --filter=blob:none --no-checkout https://github.com/BerriAI/litellm.git . \
    && git checkout --detach "${LITELLM_COMMIT}" \
    && test "$(git rev-parse HEAD)" = "${LITELLM_COMMIT}" \
    && test "$(python -c 'import tomllib; print(tomllib.load(open("pyproject.toml", "rb"))["project"]["version"])')" = "${LITELLM_VERSION}"

ENV UV_PROJECT_ENVIRONMENT=/opt/litellm \
    UV_LINK_MODE=copy \
    PATH="/opt/litellm/bin:${PATH}"

# Use the upstream lock, install only the core gateway/proxy feature set, then
# raise the Xray-reported components to their stated fix versions.
RUN uv sync --frozen --no-default-groups --no-editable --extra proxy --python python3 \
    && uv pip install --python /opt/litellm/bin/python \
        'RestrictedPython>=8.3,<9' \
        'tornado>=6.5.8' \
        'cryptography>=50.0.0,<51' \
        'aiohttp>=3.14.3,<4' \
        'mcp>=1.28.1,<2' \
        'pyasn1>=0.6.4' \
    && /opt/litellm/bin/python -c 'from importlib.metadata import version; from packaging.version import Version as V; floors={"RestrictedPython":"8.3","tornado":"6.5.8","cryptography":"50.0.0","aiohttp":"3.14.3","mcp":"1.28.1","pyasn1":"0.6.4"}; assert all(V(version(p)) >= V(v) for p,v in floors.items())' \
    && /opt/litellm/bin/python -c 'import importlib.util; assert importlib.util.find_spec("ddtrace") is None; assert importlib.util.find_spec("pypdf") is None' \
    && /opt/litellm/bin/python -c 'import litellm; import litellm.proxy.proxy_server'

FROM ${WOLFI_IMAGE} AS runtime

ARG LITELLM_VERSION
ARG LITELLM_COMMIT

RUN apk upgrade --available --no-cache \
    && apk add --no-cache --upgrade glibc \
    && apk add --no-cache ca-certificates libsndfile python3 \
    && adduser -D -u 10001 litellm

COPY --from=builder /opt/litellm /opt/litellm

ENV PATH="/opt/litellm/bin:${PATH}" \
    LITELLM_PORT=4000

WORKDIR /app
USER 10001:10001

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD python -c 'import urllib.request; urllib.request.urlopen("http://127.0.0.1:4000/health/liveliness", timeout=5)'

LABEL org.opencontainers.image.title="litellm" \
      org.opencontainers.image.description="LiteLLM AI Gateway built from pinned upstream source" \
      org.opencontainers.image.source="https://github.com/BerriAI/litellm" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${LITELLM_VERSION}" \
      org.opencontainers.image.revision="${LITELLM_COMMIT}"

ENTRYPOINT ["litellm"]
CMD ["--port", "4000"]
