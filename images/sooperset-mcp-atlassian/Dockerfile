# syntax=docker/dockerfile:1

# Single source of truth for the Python/Alpine base version used by BOTH the
# build stage and the runtime stage. Previously these were two independently
# floating tags (astral-sh/uv:python3.13-alpine for build, python:3.13-alpine
# for runtime) which drifted out of sync -- Xray caught the build stage still
# running Python 3.13.10 while the runtime stage was on 3.13.14. Pinning one
# ARG here means there is exactly one place to bump when Python/Alpine ships
# a security fix.
ARG PYTHON_IMAGE=python:3.13.15-alpine3.24

FROM ${PYTHON_IMAGE} AS builder

# uv is a standalone static binary -- copy it in rather than using astral's
# combined python+uv image, so the Python/Alpine version is controlled by
# PYTHON_IMAGE alone. Pinned to an explicit release (not :latest) so mirroring
# this build into Artifactory is reproducible.
COPY --from=ghcr.io/astral-sh/uv:0.12.5 /uv /uvx /usr/local/bin/

WORKDIR /app
ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

# Allow injecting the package version at build time so that the image
# reports the correct version even without a .git directory.
ARG VERSION

# Install dependencies from the committed lockfile only. (The previous
# Dockerfile generated a throwaway lockfile from pyproject.toml+README.md
# here, then immediately discarded it in favor of the committed uv.lock in
# the step below -- that dead step is removed. The committed uv.lock is now
# the single source of truth and is kept in sync with pyproject.toml.)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    uv sync --frozen --extra wpad --no-install-project --no-dev --no-editable

# Then, copy the rest of the project source code and install it
COPY . /app
RUN if [ -n "$VERSION" ] && echo "$VERSION" | grep -qE '^[0-9]'; then \
      sed -i "s/fallback-version = \"0.0.0\"/fallback-version = \"$VERSION\"/" pyproject.toml; \
    fi
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --extra wpad --no-dev --no-editable

# Remove unnecessary files from the virtual environment before copying
RUN find /app/.venv -name '__pycache__' -type d -exec rm -rf {} + && \
    find /app/.venv -name '*.pyc' -delete && \
    find /app/.venv -name '*.pyo' -delete && \
    echo "Cleaned up .venv"

# Final stage -- same base image/version as the builder above
FROM ${PYTHON_IMAGE}

# Pick up any Alpine package security patches published after this base
# image tag was built (e.g. sqlite-libs, libuuid), and remove the ensurepip
# bundle: it ships its own copy of pip/setuptools that Xray will otherwise
# keep flagging (CVE-2018-20225, CVE-2025-47273, CVE-2026-23949, etc.), and
# this image never runs pip/ensurepip at runtime -- it only runs the
# pre-built venv copied in below.
RUN apk update && apk upgrade --no-cache && \
    rm -rf /usr/local/lib/python3.13/ensurepip && \
    rm -rf /var/cache/apk/*

# Create a non-root user 'app'
RUN adduser -D -h /home/app -s /bin/sh app
WORKDIR /app
USER app

COPY --from=builder --chown=app:app /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Disable Python output buffering for proper stdio communication
ENV PYTHONUNBUFFERED=1

# For minimal OAuth setup without environment variables, use:
# docker run -e ATLASSIAN_OAUTH_ENABLE=true -p 8000:8000 your-image
# Then provide authentication via headers:
# Authorization: Bearer <your_oauth_token>
# X-Atlassian-Cloud-Id: <your_cloud_id>

ENTRYPOINT ["mcp-atlassian"]
