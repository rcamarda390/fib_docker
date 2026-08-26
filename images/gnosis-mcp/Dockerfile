# syntax=docker/dockerfile:1.7
# =============================================================================
# gnosis-mcp — air-gap variant (v11)
# =============================================================================
# Patch: gnosis-mcp 0.14.0 rest.py does not wire session_manager.run() into
# the Starlette lifespan when mounting StreamableHTTP alongside REST API.
# This causes RuntimeError: Task group is not initialized on every /mcp request.
# Fix: inject a combined lifespan that runs both REST backend AND session_manager.
# Security: Python 3.13 plus current Debian updates; PAM and attr are removed
# because this non-login service does not use them. SQLite is replaced with a
# checksum-pinned upstream build that retains the required FTS5 and extension
# functionality. Debian Trixie still has no supported fixes for the remaining
# glibc findings (CVE-2026-5435, CVE-2026-5928, and CVE-2026-5450).
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

# Debian Trixie's sqlite3 source remains vulnerable to CVE-2026-11822 and
# CVE-2026-11824. Build the fixed upstream release from SQLite's official
# amalgamation archive. SHA3-256 is published on sqlite.org/download.html.
# FTS5 is load-bearing for gnosis-mcp and must remain compiled in.
ARG SQLITE_AUTOCONF=3530400
ARG SQLITE_VERSION=3.53.4
ARG SQLITE_SHA3=454e45f61c6bd75b7420e7190732dea03ce6639c63ada47bbc592f67fc340338
RUN curl -fsSL "https://sqlite.org/2026/sqlite-autoconf-${SQLITE_AUTOCONF}.tar.gz" \
        -o /tmp/sqlite.tar.gz \
    && python -c "import hashlib; p='/tmp/sqlite.tar.gz'; actual=hashlib.sha3_256(open(p,'rb').read()).hexdigest(); expected='${SQLITE_SHA3}'; assert actual == expected, f'{actual} != {expected}'" \
    && tar -xzf /tmp/sqlite.tar.gz -C /tmp \
    && cd "/tmp/sqlite-autoconf-${SQLITE_AUTOCONF}" \
    && CFLAGS="-O2 -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_COLUMN_METADATA -DSQLITE_ENABLE_DBSTAT_VTAB -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_UNLOCK_NOTIFY -DSQLITE_SECURE_DELETE" \
        ./configure --prefix=/opt/sqlite --disable-static --enable-fts5 \
    && make -j"$(nproc)" \
    && make install \
    && test "$(LD_LIBRARY_PATH=/opt/sqlite/lib /opt/sqlite/bin/sqlite3 :memory: 'select sqlite_version();')" = "${SQLITE_VERSION}" \
    && rm -rf /tmp/sqlite.tar.gz "/tmp/sqlite-autoconf-${SQLITE_AUTOCONF}"

WORKDIR /build

ARG GNOSIS_VERSION=0.14.1
ARG EXTRAS="embeddings"
COPY requirements.lock /build/requirements.lock
# gnosis-mcp is locked to its PyPI release, so the extras are resolved away and
# no longer appear in the requirement line. sqlite-vec is pulled in by the
# embeddings extra alone, so it stands in as the marker that the lock really was
# compiled with that extra.
RUN test "$EXTRAS" = "embeddings" \
    && grep -qE "^gnosis-mcp==${GNOSIS_VERSION}( |$)" /build/requirements.lock \
    && grep -qE "^sqlite-vec==" /build/requirements.lock \
    && pip install --require-hashes --prefix=/install -r /build/requirements.lock \
    && SITE_PACKAGES="$(find /install/lib -type d -name site-packages -print -quit)" \
    && test "$(PYTHONPATH="$SITE_PACKAGES" python -c 'import importlib.metadata; print(importlib.metadata.version("gnosis-mcp"))')" = "$GNOSIS_VERSION"

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

ARG SQLITE_VERSION=3.53.4
COPY --from=builder /opt/sqlite/lib/libsqlite3.so* /usr/local/lib/

# Xray's fixed floor for CVE-2026-63072, CVE-2026-54874,
# CVE-2026-18798, CVE-2026-63076, CVE-2026-63075, CVE-2026-14457,
# CVE-2026-14456, CVE-2026-63074, CVE-2026-63073, and CVE-2026-75803.
# Keep this as a minimum rather than an exact pin so later Debian security
# revisions remain eligible. The build fails closed if the mirror is stale.
ARG OPENSSL_MIN_VERSION=3.5.7-1~deb13u2

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        libgomp1 \
        libssl3t64 \
        openssl \
        openssl-provider-legacy \
    && for package in libssl3t64 openssl openssl-provider-legacy; do \
        installed_version="$(dpkg-query -W -f='${Version}' "$package")"; \
        echo "$package=$installed_version"; \
        dpkg --compare-versions "$installed_version" ge "$OPENSSL_MIN_VERSION" \
            || { echo "$package is below required version $OPENSSL_MIN_VERSION" >&2; exit 1; }; \
       done \
    && useradd --system --create-home --home-dir /home/gnosis --shell /bin/false gnosis \
    && apt-get purge -y --auto-remove --allow-remove-essential perl-base perl-modules-5.40 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /usr/share/debconf \
    && printf '#!/bin/sh\nexit 0\n' > /usr/share/debconf/frontend \
    && chmod 0755 /usr/share/debconf/frontend \
    && dpkg --purge --force-depends --force-remove-essential --force-remove-protected \
        bsdutils gzip libblkid1 libncursesw6 libsmartcols1 libtinfo6 \
        libuuid1 ncurses-base util-linux libacl1 libattr1 liblastlog2-2 \
        libpam-runtime libpam-modules libpam0g libsqlite3-0 \
        ncurses-bin libmount1 login mount \
    && rm -rf /usr/share/debconf \
    && ldconfig

COPY --from=builder /install             /usr/local
COPY --from=builder /gnosis-model-cache  /gnosis-model-cache

# Remove pip and its vendored vulnerable dependencies from the runtime.
# CVE-2026-23949, CVE-2025-47273 (setuptools); CVE-2026-57585 (msgpack)
# pip vendors its own dependency tree; pip's vendored pinned versions are:
#   setuptools==70.3.0
#   msgpack==1.1.2
# Bumping PIP_VERSION cannot fix these because the vendored pins travel with
# whatever pip release is installed; only removing pip removes the files.
# The ensurepip bundled wheel carries the same vendored tree, so it goes too.
# Nothing in this image invokes pip at runtime: gnosis-mcp has all deps from
# requirements.lock pre-installed, and there is no entrypoint that needs pip.
RUN rm -rf /usr/local/lib/python*/site-packages/pip \
           /usr/local/lib/python*/site-packages/pip-*.dist-info \
           /usr/local/lib/python*/ensurepip/_bundled \
           /usr/lib/python*/dist-packages/pip* \
           /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip* \
           /usr/bin/pip /usr/bin/pip3 /usr/bin/pip* \
           /root/.cache 2>/dev/null || true

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

# Verify that security removals and runtime functionality both succeeded.
RUN ! command -v pip \
    && ! python -c "import pip" 2>/dev/null \
    && test -z "$(find /usr/local /usr/lib -type f -path '*/pip/_vendor/*' -print -quit)" \
    && test -z "$(find /usr/local /usr/lib -type f -path '*/ensurepip/_bundled/*' -print -quit)" \
    && for package in libattr1 libpam0g libpam-modules libpam-runtime libsqlite3-0; do \
        package_state="$(dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null || true)"; \
        test "$package_state" != "installed" || { echo "$package is still installed" >&2; exit 1; }; \
       done \
    && python -c "import sqlite3, sqlite_vec; assert sqlite3.sqlite_version == '${SQLITE_VERSION}'; db=sqlite3.connect(':memory:'); db.execute('create virtual table docs using fts5(body)'); db.execute(\"insert into docs values ('security fixed')\"); assert db.execute(\"select count(*) from docs where docs match 'fixed'\").fetchone()[0] == 1; db.enable_load_extension(True); db.load_extension(sqlite_vec.loadable_path()); db.execute('create virtual table vectors using vec0(embedding float[2])')" \
    && python -c "from importlib.metadata import version; from packaging.version import Version; assert Version(version('setuptools')) >= Version('80.10.0'); assert Version(version('msgpack')) >= Version('1.2.1')" \
    && python -c "import gnosis_mcp; print('Verification: gnosis-mcp OK')"

ARG GNOSIS_VERSION=0.14.1
ARG EMBED_MODEL="MongoDB/mdbr-leaf-ir"
LABEL org.opencontainers.image.title="gnosis-mcp" \
      org.opencontainers.image.description="Self-hosted MCP docs server — air-gap variant, ONNX model pre-bundled." \
      org.opencontainers.image.source="https://github.com/nicholasglazer/gnosis-mcp" \
      org.opencontainers.image.licenses="MIT" \
      gnosis.airgap="true" \
      gnosis.embed-model="${EMBED_MODEL}" \
      gnosis.gnosis-version="${GNOSIS_VERSION}" \
      gnosis.patch="rest.py-combined-lifespan" \
      gnosis.image-version="v11"

ENTRYPOINT ["gnosis-mcp"]
CMD ["serve", "--transport", "streamable-http", "--rest"]
