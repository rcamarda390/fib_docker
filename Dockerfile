FROM python:3.13-slim-bookworm

USER root
ARG DEBIAN_FRONTEND=noninteractive

# ============================================================
# OS upgrades + minimal tools
# ============================================================
RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        jq \
        less \
        openssh-client \
        postgresql-client \
        procps; \
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
# pip behavior
# ============================================================
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# OPTIONAL (recommended): force pip to Artifactory only
# ENV PIP_INDEX_URL="https://<ARTIFACTORY_HOST>/api/pypi/<REPO>/simple" \
#     PIP_EXTRA_INDEX_URL="" \
#     PIP_TRUSTED_HOST="<ARTIFACTORY_HOST>"

# ============================================================
# Python packages (no airflow, no fastapi)
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

RUN mkdir -p /workspaces
WORKDIR /workspaces
