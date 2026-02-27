FROM python:3.13-slim-bookworm

USER root
ARG DEBIAN_FRONTEND=noninteractive

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# ============================================================
# OS upgrades + minimal tools (keep git; drop openssh-client, psql)
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
# Build deps (temporary) for pip wheels; removed later
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
# Python packages (devcontainer tooling)
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
# Build manifest (compare vs Xray)
# ============================================================
RUN set -eux; \
    mkdir -p /usr/local/share/build-manifest; \
    dpkg-query -W -f='${Package}\t${Version}\n' | sort > /usr/local/share/build-manifest/dpkg-manifest.tsv; \
    apt-mark showmanual | sort > /usr/local/share/build-manifest/apt-manual.txt; \
    pip freeze | sort > /usr/local/share/build-manifest/pip-freeze.txt; \
    python -c "import sqlite3; print(sqlite3.sqlite_version)" > /usr/local/share/build-manifest/python-sqlite-version.txt; \
    python -V > /usr/local/share/build-manifest/python-version.txt

RUN mkdir -p /workspaces
WORKDIR /workspaces
