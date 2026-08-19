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
RUN uv sync --frozen --extra proxy --extra bedrock --no-dev --no-editable
# There is deliberately no pip step here. `uv sync` builds /opt/venv without
# seeding pip or setuptools, so any `pip`, `/opt/venv/bin/pip`, or
# `python -m pip` invocation against this venv fails with "No module named
# pip" -- use `uv pip install --python /opt/venv/bin/python` if a package ever
# genuinely needs adding. The setuptools/msgpack upgrades that used to live
# here targeted packages that headroom 0.35.0 does not install: uv resolves 69
# packages into this venv and neither is among them, so the upgrade would have
# added CVE surface rather than removing it. Trivy scans the built image and
# will report either package if it reappears with a known advisory (reported
# only, not blocking: this image leaves block_on_scan_failure at its default).
RUN cd /tmp && PATH="/opt/venv/bin:${PATH}" python -c \
    "from headroom._core import DiffCompressor, SmartCrusher; \
     print(f'Headroom Rust core OK: {DiffCompressor.__name__}, {SmartCrusher.__name__}')"
RUN test "$(PATH="/opt/venv/bin:${PATH}" python -c 'import importlib.metadata; print(importlib.metadata.version("headroom-ai"))')" = "$HEADROOM_VERSION"
RUN PATH="/opt/venv/bin:${PATH}" python -c \
    "import boto3, botocore; \
     print(f'Bedrock dependencies OK: boto3 {boto3.__version__}, botocore {botocore.__version__}')"

FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
ARG PYTHON_VERSION

ENV HEADROOM_HOST=0.0.0.0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/venv/bin:${PATH}

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
RUN rm -rf /usr/local/lib/python${PYTHON_VERSION}/site-packages/pip \
           /usr/local/lib/python${PYTHON_VERSION}/site-packages/pip-*.dist-info \
           /usr/local/lib/python${PYTHON_VERSION}/ensurepip/_bundled \
           /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip${PYTHON_VERSION} \
           /root/.cache
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
# Debian bookworm CVEs: 15 findings with no fixed version, classified as
# <no-dsa> "Minor issue" in Debian security tracker. These packages are not
# used at runtime:
#   gzip           CVE-2026-41992 -- nothing shells out to gzip or untars at
#                                    runtime. Note this is the gzip *binary*
#                                    only: Python's zlib module links
#                                    libz.so.1 from zlib1g dynamically, so
#                                    zlib1g itself must stay.
#   ncurses-bin    CVE-2025-69720 -- bash links libtinfo.so.6; headroom uses
#   ncurses-base                      dash for entrypoint and Python for
#   libtinfo6                         payload, so none of it is used
#   libacl1        CVE-2026-54369 -- only cp/mv/install/tar link libacl.so.1;
#   libattr1       CVE-2026-54371    headroom uses mkdir/chown/cat only
#   libpam0g       CVE-2025-8941  -- headroom doesn't authenticate through PAM;
#   libpam-modules                    gosu uses plain setuid/setgid, user lookup
#   libpam-runtime                    via glibc NSS, not PAM
#   libtasn1-6     CVE-2025-13151 -- only used for X.509 cert parsing; Python's
#                                    ssl uses system certs, doesn't need libtasn1
#
# libsqlite3-0 is deliberately NOT purged, and must not be added to the list
# below. Python 3.13's sqlite3 is a dynamically linked extension
# (lib-dynload/_sqlite3.*.so -> libsqlite3.so.0), and headroom imports sqlite3
# on the `mcp serve` path (compression cache store, memory store, Codex thread
# recovery). Purging it builds a green image that dies at startup with
# "ImportError: libsqlite3.so.0: cannot open shared object file". That shipped
# once and had to be reverted; the verification step at the end of this stage
# now fails the build if it ever happens again.
#
# The scanner reports bookworm's libsqlite3-0 3.40.1-2+deb12u2 as CVE-2025-7458
# (CVSS 9.1, CWE-190), and Debian additionally tracks CVE-2025-7709 and
# CVE-2026-11822/-11824/-50812/-50813 against it. Every one is <no-dsa> "Minor
# issue" with no fixed version for bookworm -- CVE-2025-7458 is fixed only in
# 3.42.0-1 -- so `apt-get upgrade` above can never clear them. CVE-2025-7458
# requires an attacker who can execute arbitrary SQL; upstream's fix (check-in
# 12ad822d9b827777) is a query-planner correctness fix for
# `SELECT DISTINCT <constant terms> ... ORDER BY`, not memory corruption.
# headroom builds all of its own SQL and never executes SQL supplied by an MCP
# client, so that precondition does not exist here. Actually clearing the
# finding requires SQLite >= 3.42, i.e. a base-image move to trixie or a
# vendored upstream SQLite -- a deliberate change, not a purge.
# Two CVEs are truly unfixable without base image upgrade:
#   CVE-2026-5435  (glibc) -- No upstream fix at all yet
#   CVE-2026-5928  (glibc) -- Fixed only in glibc 2.42. trixie ships 2.41, so a
#                             move to trixie would NOT clear it; 2.42 first
#                             appears in forky/sid. The same is true of
#                             CVE-2026-5450, which the scanner reports against
#                             libc-bin: <no-dsa> in bookworm and trixie alike.
#                             It needs scanf("%mc") with an explicit field width
#                             above 1024, which CPython never calls.
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
RUN mkdir -p /usr/share/debconf \
 && printf '#!/bin/sh\nexit 0\n' > /usr/share/debconf/frontend \
 && chmod 0755 /usr/share/debconf/frontend \
 && dpkg --purge --force-depends --force-remove-essential --force-remove-protected \
      gzip ncurses-bin ncurses-base libtinfo6 \
      libacl1 libattr1 \
      libpam-runtime libpam-modules libpam0g libtasn1-6 \
 && rm -rf /usr/share/debconf
COPY --from=builder /opt/venv /opt/venv
COPY mcp-smoke.py /usr/local/bin/mcp-smoke.py
COPY entrypoint.sh /usr/local/bin/headroom-entrypoint
RUN chmod +x /usr/local/bin/headroom-entrypoint
# Verify that purged packages didn't break critical runtime functionality.
# `python -c "import sys"` proved nothing: it passed while libsqlite3-0 was
# purged, so a green build shipped an image that died on startup. Import every
# stdlib module whose backing shared library a purge could plausibly remove and
# actually exercise sqlite3 and ssl, so a bad purge fails here -- in the stage
# that caused it -- instead of surfacing later as an opaque MCP startup error.
RUN PATH="/opt/venv/bin:${PATH}" python -c \
    "import ssl, sqlite3, hashlib, lzma, bz2, ctypes, zlib, socket; \
     sqlite3.connect(':memory:').execute('select 1').fetchone(); \
     ssl.create_default_context(); \
     print('Verification: Python stdlib (sqlite3, ssl, compression) OK')" \
 && /bin/dash -c "echo 'Verification: dash entrypoint shell OK'" \
 && ! command -v perl \
 && ! command -v gzip \
 && ! command -v tput \
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
