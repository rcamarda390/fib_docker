# syntax=docker/dockerfile:1.7

ARG HEADROOM_VERSION=0.37.0
ARG HEADROOM_COMMIT=32d7ca4577d599b8a5f811ada74cf31504302c9d
ARG PYTHON_VERSION=3.13.15
ARG PYTHON_ABI=3.13
ARG DEBIAN_SUITE=trixie
ARG PIP_VERSION=26.2.1
ARG LITELLM_VERSION=1.96.2
ARG RUSTUP_VERSION=1.28.2
ARG SQLITE_VERSION=3.53.4
ARG SQLITE_AUTOCONF=3530400
ARG SQLITE_SHA3=454e45f61c6bd75b7420e7190732dea03ce6639c63ada47bbc592f67fc340338

FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS source
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git clone --depth 1 --branch "v${HEADROOM_VERSION}" \
       https://github.com/headroomlabs-ai/headroom.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$HEADROOM_COMMIT"

FROM python:${PYTHON_VERSION}-slim-${DEBIAN_SUITE} AS builder
ARG HEADROOM_VERSION
ARG PYTHON_VERSION
ARG PIP_VERSION
ARG LITELLM_VERSION
ARG RUSTUP_VERSION
ARG SQLITE_VERSION
ARG SQLITE_AUTOCONF
ARG SQLITE_SHA3

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

# Debian trixie's SQLite fixes CVE-2025-7458, but its 3.46 package predates
# the 3.53.2 fixes for CVE-2026-11822 and CVE-2026-11824. Build the current
# upstream 3.53.4 amalgamation as a shared library, verify SQLite's published
# SHA3-256, and retain FTS5 rather than avoiding the vulnerable code by
# disabling application functionality.
RUN set -eux; \
    curl --proto '=https' --tlsv1.2 --fail --silent --show-error --location \
      "https://sqlite.org/2026/sqlite-autoconf-${SQLITE_AUTOCONF}.tar.gz" \
      --output /tmp/sqlite.tar.gz; \
    python -c "import hashlib; actual=hashlib.file_digest(open('/tmp/sqlite.tar.gz','rb'),'sha3_256').hexdigest(); assert actual == '${SQLITE_SHA3}', actual"; \
    tar -xzf /tmp/sqlite.tar.gz -C /tmp; \
    mkdir -p /opt/sqlite/lib; \
    cc -O2 -fPIC -shared -Wl,-soname,libsqlite3.so.0 \
      -DSQLITE_THREADSAFE=1 \
      -DSQLITE_ENABLE_COLUMN_METADATA \
      -DSQLITE_ENABLE_DBSTAT_VTAB \
      -DSQLITE_ENABLE_FTS5 \
      -DSQLITE_ENABLE_MATH_FUNCTIONS \
      -DSQLITE_ENABLE_RTREE \
      "/tmp/sqlite-autoconf-${SQLITE_AUTOCONF}/sqlite3.c" \
      -ldl -lpthread -lm \
      -o /opt/sqlite/lib/libsqlite3.so.0.8.6; \
    ln -s libsqlite3.so.0.8.6 /opt/sqlite/lib/libsqlite3.so.0; \
    LD_LIBRARY_PATH=/opt/sqlite/lib python -c "import sqlite3; assert sqlite3.sqlite_version == '${SQLITE_VERSION}', sqlite3.sqlite_version; db=sqlite3.connect(':memory:'); db.execute('create virtual table docs using fts5(body)'); db.execute('insert into docs values (\"headroom\")'); assert db.execute('select body from docs where docs match \"headroom\"').fetchone() == ('headroom',)"; \
    rm -rf /tmp/sqlite.tar.gz "/tmp/sqlite-autoconf-${SQLITE_AUTOCONF}"
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
# The proxy extra includes Headroom's MCP server, compression, and general
# LiteLLM backends. The bedrock extra adds boto3 and botocore for AWS SDK
# support required to reach AWS Bedrock from an air-gapped GovCloud environment.
RUN uv sync --frozen --extra proxy --extra bedrock --no-dev --no-editable
# Xray XRAY-1062440 reports Headroom 0.37.0's locked LiteLLM 1.88.1 and fixes
# it in 1.96.2. Keep the immutable upstream lock for every other dependency,
# then make this single, explicit downstream security override. uv mutates the
# existing venv without installing pip or setuptools. Remove this carry when a
# future Headroom release locks LiteLLM >= 1.96.2.
RUN uv pip install --python /opt/venv/bin/python --upgrade \
      "litellm==${LITELLM_VERSION}" \
    && test "$(PATH="/opt/venv/bin:${PATH}" python -c 'import importlib.metadata; print(importlib.metadata.version("litellm"))')" = "$LITELLM_VERSION" \
    && ! PATH="/opt/venv/bin:${PATH}" python -c "import pip" 2>/dev/null
# The setuptools/msgpack upgrades that used to live here targeted packages
# that Headroom does not install: neither appears in the proxy+bedrock
# resolution. Re-check that on an upstream version bump with `uv export
# --frozen --extra proxy --extra bedrock --no-dev`. Trivy reports any
# reappearance with a known advisory.
RUN cd /tmp && PATH="/opt/venv/bin:${PATH}" python -c \
    "from headroom._core import DiffCompressor, SmartCrusher; \
     print(f'Headroom Rust core OK: {DiffCompressor.__name__}, {SmartCrusher.__name__}')"
RUN test "$(PATH="/opt/venv/bin:${PATH}" python -c 'import importlib.metadata; print(importlib.metadata.version("headroom-ai"))')" = "$HEADROOM_VERSION"
RUN PATH="/opt/venv/bin:${PATH}" python -c \
    "import boto3, botocore; \
     print(f'Bedrock dependencies OK: boto3 {boto3.__version__}, botocore {botocore.__version__}')"

# ---------------------------------------------------------------------------
# Downstream carry: Cline's OpenAI-compatible transport to AWS Bedrock.
# Short-lived -- delete this block, the two ENV lines in the runtime stage that
# reference it, and the two scripts once the fixes land upstream. See
# CLINE_BEDROCK.md.
#
# Apply the patch directly to the venv built from the pinned upstream source so
# one action produces the complete deployable image. The patch fails closed if
# upstream's two OpenAI call sites change, and the regression script verifies
# both streaming and non-streaming Bedrock behavior.
COPY patch-headroom-bedrock-openai.py bedrock-openai-regression.py /tmp/
RUN set -eu; \
    export PATH="/opt/venv/bin:${PATH}"; \
    cd /tmp; \
    target="$(python -c 'import headroom.backends.litellm as m; print(m.__file__)')"; \
    python /tmp/patch-headroom-bedrock-openai.py "$target"; \
    python -m py_compile "$target"; \
    python /tmp/bedrock-openai-regression.py
# ---------------------------------------------------------------------------

# Pre-cache Hugging Face models needed for Kompress compression in the air-gapped runtime.
# When HF_HUB_OFFLINE=1 and TRANSFORMERS_OFFLINE=1 are set at runtime, these models
# must already be present in the image cache. Kompress uses:
#   - chopratejas/kompress-v2-base: ONNX model for text importance scoring
#   - answerdotai/ModernBERT-base: Tokenizer (shared with Kompress model)
# Only the required ONNX artifacts and tokenizer are downloaded, not full weights.
# Timeout/retry handling: HF downloads can timeout; skip this step if network fails.
ENV HF_HOME=/opt/headroom-cache/huggingface
RUN mkdir -p /opt/headroom-cache/huggingface || true
RUN <<EOF
#!/bin/sh
set -eu
export PATH="/opt/venv/bin:${PATH}"
python << 'HFCACHE'
import os
import sys
from huggingface_hub import hf_hub_download
from transformers import AutoTokenizer

hf_home = '/opt/headroom-cache/huggingface'
os.environ['HF_HOME'] = hf_home

# Download Kompress model artifacts: prefer int8-wo (weight-only quantized),
# fallback to fp32 and older int8 for compatibility
kompress_model = 'chopratejas/kompress-v2-base'
kompress_onnx_files = [
    'onnx/kompress-int8-wo.onnx',
    'onnx/kompress-fp32.onnx',
    'onnx/kompress-int8.onnx',
]

onnx_success = False
for onnx_file in kompress_onnx_files:
    try:
        hf_hub_download(
            repo_id=kompress_model,
            filename=onnx_file,
            repo_type="model",
            resume_download=True,
            force_download=False,
        )
        print(f"✓ Downloaded {kompress_model}/{onnx_file}")
        onnx_success = True
        break  # Use first successfully downloaded artifact
    except Exception as e:
        print(f"⚠ Could not download {onnx_file}: {e}")

if not onnx_success:
    print("⚠ Warning: Could not download Kompress ONNX artifact, models will be downloaded at runtime")
else:
    # Download tokenizer from ModernBERT-base (Kompress reuses this exact tokenizer)
    tokenizer_model = "answerdotai/ModernBERT-base"
    try:
        AutoTokenizer.from_pretrained(
            tokenizer_model,
            trust_remote_code=True,
        )
        print(f"✓ Downloaded tokenizer from {tokenizer_model}")
    except Exception as e:
        print(f"⚠ Warning: Could not download tokenizer from {tokenizer_model}: {e}")

print("✓ Hugging Face model cache population completed (may be partial)")
HFCACHE
EOF


FROM python:${PYTHON_VERSION}-slim-${DEBIAN_SUITE} AS runtime
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
ARG LITELLM_VERSION
ARG PYTHON_VERSION
ARG PYTHON_ABI
ARG SQLITE_VERSION

ENV HEADROOM_HOST=0.0.0.0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/venv/bin:${PATH} \
    HF_HOME=/opt/headroom-cache/huggingface \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1 \
    HF_HUB_DISABLE_TELEMETRY=1 \
    LITELLM_LOCAL_MODEL_COST_MAP=True \
    HEADROOM_UPDATE_CHECK=off

# Skip only Headroom's external upstream readiness probe. The air-gapped
# GovCloud runtime intentionally cannot reach the Anthropic HTTP endpoint;
# this does not change TLS verification for real Bedrock traffic.
ENV HEADROOM_SKIP_UPSTREAM_CHECK=1

# Enable Headroom's live per-request output-token shaping. No fixed verbosity
# level is set; a learned profile remains a deployment-time choice.
ENV HEADROOM_OUTPUT_SHAPER=1

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/headroom \
      --shell /usr/sbin/nologin headroom \
    && mkdir -p /home/headroom/.headroom \
    && chown -R headroom:headroom /home/headroom
# Remove the base interpreter's pip instead of upgrading it. Nothing in this
# image runs pip: the payload is /opt/venv, which uv builds without seeding
# pip, and the entrypoint invokes /opt/venv/bin/headroom directly.
#
# Upgrading pip here is what put the scanner's three "fixable" findings in the
# image in the first place. pip vendors its own dependency tree, and
# pip 26.2.1's pip/_vendor/vendor.txt pins exactly the versions reported:
#   setuptools==70.3.0  -> CVE-2026-23949, CVE-2025-47273
#   msgpack==1.1.2      -> CVE-2026-57585
# Bumping PIP_VERSION cannot fix those, because the vendored pins travel with
# whatever pip release is installed; only removing pip removes the files. The
# ensurepip bundled wheel carries the same vendored tree, so it goes too.
#
# Neither finding was reachable -- nothing invokes pip at runtime, and the
# vendored msgpack is the pure-Python fallback with no _cmsgpack extension,
# while CVE-2026-57585 is a use-after-free that can only exist in the C
# extension -- but the code is genuinely gone now rather than argued away.
# The verification at the end of this stage asserts pip is absent, so this
# cannot silently regress into a no-op.
RUN rm -rf /usr/local/lib/python${PYTHON_ABI}/site-packages/pip \
           /usr/local/lib/python${PYTHON_ABI}/site-packages/pip-*.dist-info \
           /usr/local/lib/python${PYTHON_ABI}/ensurepip/_bundled \
           /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip${PYTHON_ABI} \
           /root/.cache
# Every perl-base CVE the scanner reports against the Debian runtime is published with no
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
# Scanner-visible packages that are not used at runtime are removed after the
# final apt operation:
#   gzip            -- nothing shells out to gzip or untars at runtime. Python
#                      still retains the dynamically linked zlib module.
#   ncurses packages -- CVE-2025-69720 is in the infocmp CLI. Headroom has no
#                       terminal UI, so both the CLI and Python's optional
#                       _curses modules are removed instead of retaining the
#                       source-package finding through libncursesw6.
#   libacl1        CVE-2026-54369 -- only cp/mv/install/tar link libacl.so.1;
#   libattr1       CVE-2026-54371    headroom uses mkdir/chown/cat only
#   libpam0g       CVE-2025-8941  -- headroom doesn't authenticate through PAM;
#   libpam-modules, libpam-modules-bin, libpam-runtime
#                                     user lookup uses glibc NSS, not PAM
#   libtasn1-6     CVE-2025-13151 -- only used for X.509 cert parsing; Python's
#                                    ssl uses system certs, doesn't need libtasn1
#   openssl         -- the CLI is unused; Python ssl retains trixie's patched
#                      libssl runtime package.
#
# Headroom imports sqlite3 on the `mcp serve` path (compression cache store,
# memory store, and Codex thread recovery), so SQLite cannot simply disappear.
# The builder compiles the verified 3.53.4 upstream release; copy it into the
# loader's preferred /usr/local path, then remove Debian's older libsqlite3-0
# package so scanners see only the remediated implementation. The final check
# exercises both ordinary queries and FTS5 through Python's real extension.
#
# Three glibc findings remain without a fix in Debian stable:
#   CVE-2026-5450 and CVE-2026-5928 are fixed in >= 2.42; CVE-2026-5435 is
#   fixed in >= 2.43. Debian trixie ships 2.41 and classifies all three as
#   <no-dsa> minor issues. Forky currently carries the fixes, but moving a
#   production image from stable onto testing for libc alone is not supported.
# dpkg is used instead of `apt-get purge --auto-remove` because gzip and
# ncurses-bin are Essential and apt would cascade into debconf. No apt
# operations run after this layer, so unsatisfied dependencies are inert.
#
# libpam-modules needs both halves of this next step. apt cannot do it:
# util-linux PreDepends on libpam-modules, and apt will not break a PreDepends,
# so it re-selects the package for install and declines. dpkg can force past
# that -- util-linux is on the very line below -- but its postrm execs
# /usr/share/debconf/frontend, and the perl-base purge above cascades into
# debconf, so the script exits 127 and fails the build. The stub below
# satisfies the exec so the purge completes and dpkg records it as such.
# Skipping that cleanup is harmless: it only drops the package's entries from
# the debconf database. dpkg removes the package's files either way.
COPY --from=builder /opt/sqlite/lib/ /usr/local/lib/
RUN ldconfig \
 && rm -f /usr/local/lib/python${PYTHON_ABI}/lib-dynload/_curses*.so \
 && mkdir -p /usr/share/debconf \
 && printf '#!/bin/sh\nexit 0\n' > /usr/share/debconf/frontend \
 && chmod 0755 /usr/share/debconf/frontend \
 && dpkg --purge --force-depends --force-remove-essential --force-remove-protected \
      gzip ncurses-bin ncurses-base libtinfo6 libncursesw6 \
      libacl1 libattr1 \
      libpam-runtime libpam-modules libpam-modules-bin libpam0g libtasn1-6 \
      libsqlite3-0 openssl \
 && rm -rf /usr/share/debconf
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/headroom-cache /opt/headroom-cache
COPY mcp-smoke.py /usr/local/bin/mcp-smoke.py
COPY entrypoint.sh /usr/local/bin/headroom-entrypoint
RUN find /usr/local/lib/python${PYTHON_ABI} /opt/venv \
      -name '_curses*.so' -delete \
    && chmod +x /usr/local/bin/headroom-entrypoint \
    && chown -R headroom:headroom /opt/headroom-cache
# Verify that purged packages didn't break critical runtime functionality.
# `python -c "import sys"` proved nothing: it passed while libsqlite3-0 was
# purged, so a green build shipped an image that died on startup. Import every
# stdlib module whose backing shared library a purge could plausibly remove and
# actually exercise sqlite3 and ssl, so a bad purge fails here -- in the stage
# that caused it -- instead of surfacing later as an opaque MCP startup error.
RUN PATH="/opt/venv/bin:${PATH}" python -c \
    "import importlib.util, ssl, sqlite3, hashlib, lzma, bz2, ctypes, zlib, socket; \
     assert sqlite3.sqlite_version == '${SQLITE_VERSION}', sqlite3.sqlite_version; \
     sqlite3.connect(':memory:').execute('select 1').fetchone(); \
     db=sqlite3.connect(':memory:'); db.execute('create virtual table docs using fts5(body)'); db.execute('insert into docs values (\"headroom\")'); assert db.execute('select body from docs where docs match \"headroom\"').fetchone() == ('headroom',); \
     assert importlib.util.find_spec('_curses') is None; \
     ssl.create_default_context(); \
     print(f'Verification: Python stdlib (SQLite {sqlite3.sqlite_version}, FTS5, ssl, compression) OK')" \
 && PATH="/opt/venv/bin:${PATH}" python -c \
    "import boto3, botocore, importlib.metadata, litellm; \
     assert importlib.metadata.version('litellm') == '${LITELLM_VERSION}'; \
     print(f'Verification: LiteLLM {importlib.metadata.version(\"litellm\")}; AWS dependencies (boto3 {boto3.__version__}, botocore {botocore.__version__}) OK')" \
 && { PATH="/opt/venv/bin:${PATH}" python -c \
    "import awscrt; print(f'  awscrt {awscrt.__version__} also available')" || true; } \
 && /bin/dash -c "echo 'Verification: dash entrypoint shell OK'" \
 && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' zlib1g)" ge '1:1.3.dfsg+really1.3.1-1' \
 && dpkg --compare-versions "$(dpkg-query -W -f='${Version}' libssl3t64)" ge '3.5.7-1~deb13u2' \
 && dpkg-query -W libc6 zlib1g libssl3t64 \
 && ! dpkg-query -W libsqlite3-0 libpam-modules-bin libncursesw6 openssl 2>/dev/null \
 && ! command -v perl \
 && ! command -v gzip \
 && ! command -v tput \
 && ! command -v openssl \
 && ! command -v pip \
 && ! PATH="/opt/venv/bin:${PATH}" python -c "import pip" 2>/dev/null

USER headroom
WORKDIR /home/headroom
VOLUME ["/home/headroom/.headroom"]

LABEL org.opencontainers.image.title="headroom-mcp" \
      org.opencontainers.image.description="Headroom MCP server for context optimization" \
      org.opencontainers.image.source="https://github.com/headroomlabs-ai/headroom" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${HEADROOM_VERSION}" \
      org.opencontainers.image.revision="${HEADROOM_COMMIT}"

ENTRYPOINT ["/usr/local/bin/headroom-entrypoint"]
