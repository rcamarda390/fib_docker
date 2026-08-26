# syntax=docker/dockerfile:1.7

ARG PYTHON_VERSION=3.12.14
ARG ALPINE_VERSION=3.23
FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}

ARG ATLASSIAN_VERSION=0.23.1
ARG SETUPTOOLS_VERSION=84.0.0
ARG SQLITE_MIN_VERSION=3.53.4-r0

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# Security remediation for the 0.23.0-v12 Xray findings:
# - mcp-atlassian 0.23.1 fixes GHSA-5j8j-256g-vvp5 / XRAY-1057010.
# - Python 3.12.14 avoids the Python 3.14.7 findings while staying on a
#   supported stable interpreter accepted by upstream (Python >=3.10).
# - Alpine 3.23 supplies the fixed sqlite-libs 3.53.4-r0 package.
# - pip and ensurepip are build tooling only; remove their vendored setuptools
#   70.3.0 and msgpack 1.1.2 trees from the runtime after installation.
RUN apk upgrade --no-cache \
    && apk add --no-cache "sqlite-libs>=${SQLITE_MIN_VERSION}" \
    && apk info -v sqlite-libs \
    && adduser -S -D -h /home/atlassian -s /sbin/nologin atlassian \
    && pip install "setuptools==${SETUPTOOLS_VERSION}" \
    && pip install "mcp-atlassian==${ATLASSIAN_VERSION}" \
    && python -c "from importlib.metadata import version; from packaging.version import Version; assert version('mcp-atlassian') == '${ATLASSIAN_VERSION}'; assert version('setuptools') == '${SETUPTOOLS_VERSION}'; assert Version(version('atlassian-python-api')) < Version('5.0.0')" \
    && rm -rf /usr/local/lib/python*/site-packages/pip \
              /usr/local/lib/python*/site-packages/pip-*.dist-info \
              /usr/local/lib/python*/ensurepip/_bundled \
              /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip* \
              /root/.cache \
    && ! command -v pip \
    && ! python -c "import pip" 2>/dev/null \
    && test -z "$(find /usr/local/lib -type f -path '*/pip/_vendor/*' -print -quit)" \
    && test -z "$(find /usr/local/lib -type f -path '*/ensurepip/_bundled/*' -print -quit)" \
    && python -c "import sqlite3; from importlib.metadata import distributions; from packaging.version import Version; packages={d.metadata['Name'].lower(): d.version for d in distributions()}; assert sqlite3.sqlite_version_info >= (3, 53, 4); assert 'msgpack' not in packages or Version(packages['msgpack']) >= Version('1.2.1'); import mcp_atlassian" \
    && mcp-atlassian --help >/dev/null

USER atlassian
WORKDIR /home/atlassian

LABEL org.opencontainers.image.title="atlassian-mcp" \
      org.opencontainers.image.description="MCP server for Atlassian Jira and Confluence" \
      org.opencontainers.image.source="https://github.com/sooperset/mcp-atlassian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ATLASSIAN_VERSION}"

ENTRYPOINT ["mcp-atlassian"]
