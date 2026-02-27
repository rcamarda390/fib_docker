FROM python:3.13-slim-trixie

USER root
ARG DEBIAN_FRONTEND=noninteractive

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN set -eux; \
    apt-get update; \
    apt-get -y upgrade; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        jq \
        openssh-client \
        postgresql-client \
        procps \
        \
        build-essential \
        gcc \
        g++ \
        make \
        libpq-dev \
        libssl-dev \
        libffi-dev \
        zlib1g-dev; \
    \
    echo "==== OS package versions (selected) ===="; \
    dpkg-query -W -f='${Package}\t${Version}\n' \
      libsqlite3-0 sqlite3 zlib1g openssl libssl3 libc6 2>/dev/null || true; \
    echo "==== OS manifest (all) ===="; \
    dpkg-query -W -f='${Package}\t${Version}\n' | sort > /image-dpkg-manifest.tsv; \
    \
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
    pip check; \
    \
    apt-get purge -y --auto-remove \
        build-essential gcc g++ make \
        libpq-dev libssl-dev libffi-dev zlib1g-dev; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /workspaces
WORKDIR /workspaces
