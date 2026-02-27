FROM python:3.13-slim-bookworm

USER root
ARG DEBIAN_FRONTEND=noninteractive

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# ============================================================
# OS upgrades + minimal tools (keep git only)
# ============================================================
RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        jq; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Build deps (temporary) for pip wheels
# ============================================================
RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        make \
        libpq-dev \
        libssl-dev \
        libffi-dev \
        zlib1g-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# Python packages (VSCode devcontainer support)
# ============================================================
RUN set -eux; \
    python -m pip install --upgrade pip setuptools wheel; \
    pip install \
        psycopg2-binary \
        redshift-connector \
        sqlalchemy \
        alembic \
        jira \
        atlassian-python-api \
        ruff \
        sqlfluff \
        autopep8; \
    pip uninstall -y fastapi starlette || true; \
    pip check

# ============================================================
# Remove build deps to reduce surface area
# ============================================================
RUN set -eux; \
    apt-get purge -y --auto-remove \
        build-essential \
        gcc \
        g++ \
        make \
        libpq-dev \
        libssl-dev \
        libffi-dev \
        zlib1g-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# ============================================================
# CLEAR VERSION SUMMARY (visible in build logs)
# ============================================================
RUN set -eux; \
    echo "====================================================="; \
    echo "                 IMAGE VERSION SUMMARY               "; \
    echo "====================================================="; \
    echo "OS:"; \
    cat /etc/os-release; \
    echo "-----------------------------------------------------"; \
    echo "Core Libraries:"; \
    dpkg-query -W -f='${Package}\t${Version}\n' \
        libc6 libsqlite3-0 zlib1g openssl libssl3 git 2>/dev/null || true; \
    echo "-----------------------------------------------------"; \
    echo "Python:"; \
    python -V; \
    echo "SQLite (python module):"; \
    python -c "import sqlite3; print(sqlite3.sqlite_version)"; \
    echo "-----------------------------------------------------"; \
    echo "Key Python Packages:"; \
    pip show psycopg2-binary redshift-connector sqlalchemy alembic jira atlassian-python-api ruff sqlfluff autopep8 \
        | grep -E 'Name:|Version:' || true; \
    echo "====================================================="

RUN mkdir -p /workspaces
WORKDIR /workspaces
