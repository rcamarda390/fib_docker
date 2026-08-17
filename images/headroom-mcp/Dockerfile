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
RUN uv sync --frozen --extra mcp --no-dev --no-editable
# Close CVE-2026-23949 (high), CVE-2025-47273 (medium, CWE-1395) by upgrading
# setuptools from 70.3.0 to 80.10.0 (CWE-22 path traversal fix). Close
# CVE-2026-57585 (7.5, CWE-416 use-after-free) by upgrading msgpack from
# 1.1.2 to 1.2.1. These are transitive dependencies of headroom and cannot be
# upgraded via the frozen uv.lock; pip upgrades them in the built virtual
# environment without disturbing locked top-level dependencies.
RUN /opt/venv/bin/pip install --no-cache-dir --upgrade "setuptools>=80.10.0" "msgpack>=1.2.1"
RUN cd /tmp && PATH="/opt/venv/bin:${PATH}" python -c \
    "from headroom._core import DiffCompressor, SmartCrusher; \
     print(f'Headroom Rust core OK: {DiffCompressor.__name__}, {SmartCrusher.__name__}')"
RUN test "$(PATH="/opt/venv/bin:${PATH}" python -c 'import importlib.metadata; print(importlib.metadata.version("headroom-ai"))')" = "$HEADROOM_VERSION"

FROM python:${PYTHON_VERSION}-slim-bookworm AS runtime
ARG HEADROOM_VERSION
ARG HEADROOM_COMMIT
ARG PYTHON_VERSION
ARG PIP_VERSION

ENV HEADROOM_HOST=0.0.0.0 \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PATH=/opt/venv/bin:${PATH}

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --system --create-home --home-dir /home/headroom \
      --shell /usr/sbin/nologin headroom \
    && mkdir -p /home/headroom/.headroom \
    && chown -R headroom:headroom /home/headroom
# Keep the base interpreter's pip out of the scanner's vulnerable range even
# though the application itself runs from the locked virtual environment.
RUN python -m pip install --no-cache-dir --upgrade "pip==${PIP_VERSION}" \
    && rm -rf /root/.cache
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
#   gzip           CVE-2026-41992 -- Python bundles zlib statically; nothing
#                                    shells out to gzip or untars at runtime
#   ncurses-bin    CVE-2025-69720 -- bash links libtinfo.so.6; headroom uses
#   ncurses-base                      dash for entrypoint and Python for
#   libtinfo6                         payload, so none of it is used
#   libacl1        CVE-2026-54369 -- only cp/mv/install/tar link libacl.so.1;
#   libattr1       CVE-2026-54371    headroom uses mkdir/chown/cat only
#   libsqlite3-0   CVE-2026-11822 -- Python bundles sqlite3 statically; the
#                  CVE-2026-11824    NEEDED list is libatomic/libstdc++/libgcc_s/libc
#   libpam0g       CVE-2025-8941  -- headroom doesn't authenticate through PAM;
#   libpam-modules                    gosu uses plain setuid/setgid, user lookup
#   libpam-runtime                    via glibc NSS, not PAM
#   libtasn1-6     CVE-2025-13151 -- only used for X.509 cert parsing; Python's
#                                    ssl uses system certs, doesn't need libtasn1
# Two CVEs are truly unfixable without base image upgrade:
#   CVE-2026-5435  (glibc) -- No upstream fix at all yet
#   CVE-2026-5928  (glibc) -- Fixed only in glibc 2.42 (not in bookworm; requires
#                             Debian trixie or sid, which carry other tradeoffs)
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
      libacl1 libattr1 libsqlite3-0 \
      libpam-runtime libpam-modules libpam0g libtasn1-6 \
 && rm -rf /usr/share/debconf
COPY --from=builder /opt/venv /opt/venv
COPY mcp-smoke.py /usr/local/bin/mcp-smoke.py
COPY entrypoint.sh /usr/local/bin/headroom-entrypoint
RUN chmod +x /usr/local/bin/headroom-entrypoint
# Verify that purged packages didn't break critical runtime functionality.
# Python (from venv) and dash (entrypoint shell) must work; glibc is still available.
RUN PATH="/opt/venv/bin:${PATH}" python -c "import sys; sys.exit(0)" \
 && /bin/dash -c "echo 'Verification: dash entrypoint shell OK'" \
 && ! command -v perl \
 && ! command -v gzip \
 && ! command -v ncurses \
 && PATH="/opt/venv/bin:${PATH}" python -c "import ssl; print('Verification: Python ssl OK')"

USER headroom
WORKDIR /home/headroom
VOLUME ["/home/headroom/.headroom"]

LABEL org.opencontainers.image.title="headroom-mcp" \
      org.opencontainers.image.description="Headroom MCP server for context optimization" \
      org.opencontainers.image.source="https://github.com/headroomlabs-ai/headroom" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.version="${HEADROOM_VERSION}" \
      org.opencontainers.image.revision="${HEADROOM_COMMIT}"

ENTRYPOINT ["headroom-entrypoint"]
