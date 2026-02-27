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

USER airflow

# ============================================================
# Python tooling + remediation
#   - Upgrade pip tooling
#   - Remove FastAPI if present
#   - Attempt Starlette upgrade
#   - Run pip check and print starlette-related requirements
#   - Fail intentionally so build log shows blockers
# ============================================================
RUN set -eux; \
    python -m pip install --upgrade pip setuptools wheel; \
    pip uninstall -y fastapi || true

RUN set -eux; \
    pip install --upgrade "starlette>=0.49.1"; \
    echo "---- pip check (expected to fail if something pins starlette) ----"; \
    pip check || true; \
    echo "---- packages referencing starlette ----"; \
    python -c 'import importlib.metadata as md; hits=[]; \
for d in md.distributions(): \
  name=d.metadata.get("Name",""); reqs=d.requires or []; \
  [hits.append((name,r)) for r in reqs if "starlette" in r.lower()]; \
print("No installed distribution declares a dependency on starlette.") if not hits else [print(f"{n}: {r}") for n,r in sorted(hits)]'; \
    echo "---- starlette version ----"; \
    python -c 'import starlette; print(starlette.__version__)'; \
    echo "ERROR: pip dependency conflict remains; see output above."; \
    exit 1

# ============================================================
# Project deps (install after conflicts are resolved)
# ============================================================
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
