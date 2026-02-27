FROM apache/airflow:3.1.7-python3.13

USER root
ARG DEBIAN_FRONTEND=noninteractive

# Runtime tools (keep for air-gapped usefulness)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      git \
      openssh-client \
      curl \
      ca-certificates \
      jq \
      less \
      procps \
      postgresql-client \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Build deps (temporary; purged later to reduce size)
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      build-essential \
      gcc \
      g++ \
      make \
      libpq-dev \
      libssl-dev \
      libffi-dev \
      zlib1g-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# Make pip-installed CLIs visible (sqlfluff/ruff/autopep8) + reduce pip noise
ENV PATH="/home/airflow/.local/bin:${PATH}" \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Airflow image expects pip installs as airflow user
USER airflow
RUN pip install \
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

# Purge build deps to shrink image
USER root
RUN apt-get purge -y --auto-remove \
      build-essential \
      gcc \
      g++ \
      make \
      libpq-dev \
      libssl-dev \
      libffi-dev \
      zlib1g-dev \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /workspaces \
 && chown -R airflow: /workspaces

USER airflow
WORKDIR /workspaces
