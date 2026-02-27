FROM apache/airflow:3.1.7-python3.13

USER root
ARG DEBIAN_FRONTEND=noninteractive

# ============================================================
# OS upgrades (base-image CVEs)
# - Pull patched Debian packages already available in repos
# - Install runtime tools
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
# pip behavior and PATH
# ============================================================
ENV PATH="/home/airflow/.local/bin:${PATH}" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# OPTIONAL (recommended): force pip to Artifactory only
# ENV PIP_INDEX_URL="https://<ARTIFACTORY_HOST>/api/pypi/<REPO>/simple" \
#     PIP_EXTRA_INDEX_URL="" \
#     PIP_TRUSTED_HOST="<ARTIFACTORY_HOST>"

USER airflow

# ============================================================
# Highest-signal Python remediations
# - Upgrade pip tooling
# - Pin starlette to fixed version (>= 0.49.1)
# ============================================================
RUN set -eux; \
    python -m pip install --upgrade pip setuptools wheel

# If starlette is only a transitive dep, this pin forces the fix.
# If something requires an older starlette, pip will error (good: forces resolution).
RUN set -eux; \
    pip install --upgrade "starlette>=0.49.1"

# Your project deps (keep as-is, but prefer pinning via constraints later)
RUN set -eux; \
    pip install \
        psycopg2-binary \
        redshift-connector \
        sqlalchemy \
        alembic \
        jira \
        atlassian-python-api \
        ruff \
        sqlfluff \
        autopep8 \
        apache-airflow-providers-postgres

# ============================================================
# Remove build deps to reduce surface area
# ============================================================
USER root
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

RUN mkdir -p /workspaces \
    && chown -R airflow: /workspaces

USER airflow
WORKDIR /workspaces
