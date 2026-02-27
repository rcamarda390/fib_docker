FROM apache/airflow:3.1.7-python3.13

USER root
ARG DEBIAN_FRONTEND=noninteractive

# ============================================================
# OS upgrades (base-image CVEs)
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
# Python tooling
# ============================================================
RUN set -eux; \
    python -m pip install --upgrade pip setuptools wheel

# Remove FastAPI if present (pins starlette < 0.49.0)
RUN set -eux; \
    pip uninstall -y fastapi || true

# Upgrade Starlette, print blockers, then fail (so the log shows what pins it)
RUN bash -lc 'set -euo pipefail; \
  pip install --upgrade "starlette>=0.49.1"; \
  echo "---- pip check (expected to fail if something pins starlette) ----"; \
  pip check || true; \
  echo "---- packages referencing starlette ----"; \
  python - <<'"'"'PY'"'"'
import importlib.metadata as md
hits = []
for dist in md.distributions():
    name = dist.metadata.get("Name","")
    reqs = dist.requires or []
    for r in reqs:
        if "starlette" in r.lower():
            hits.append((name, r))
if not hits:
    print("No installed distribution declares a dependency on starlette.")
else:
    for name, r in sorted(hits):
        print(f"{name}: {r}")
PY
  echo "---- starlette version ----"; \
  python - <<'"'"'PY'"'"'
import starlette
print(starlette.__version__)
PY
  echo "ERROR: pip dependency conflict remains; see output above."; \
  exit 1'

# Project deps (install after conflicts are resolved)
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
