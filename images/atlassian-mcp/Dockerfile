# syntax=docker/dockerfile:1.7

ARG ALPINE_VERSION=3.23
ARG PYTHON_APK_VERSION=3.12.14-r0

# Install Python dependencies outside the runtime image. The application tree
# is copied below, while pip and its vendored packages remain in this stage.
FROM alpine:${ALPINE_VERSION} AS builder

ARG PYTHON_APK_VERSION
ARG ATLASSIAN_VERSION=0.23.1
ARG SETUPTOOLS_VERSION=84.0.0

RUN apk upgrade --no-cache \
    && apk add --no-cache \
        "python3=${PYTHON_APK_VERSION}" \
        py3-pip \
    && python3 -m pip install \
        --break-system-packages \
        --no-cache-dir \
        --no-compile \
        --prefix=/opt/atlassian \
        "setuptools==${SETUPTOOLS_VERSION}" \
        "mcp-atlassian==${ATLASSIAN_VERSION}"

FROM alpine:${ALPINE_VERSION}

ARG PYTHON_APK_VERSION
ARG ATLASSIAN_VERSION=0.23.1
ARG SETUPTOOLS_VERSION=84.0.0
ARG SQLITE_MIN_VERSION=3.53.4-r0

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/atlassian/lib/python3.12/site-packages \
    PATH=/opt/atlassian/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Use Alpine's packaged Python so scanners resolve the interpreter version
# from authoritative APK metadata instead of fingerprinting the source-built
# interpreter in the Docker Official Image. Pip and ensurepip are absent from
# this runtime stage by construction.
RUN apk upgrade --no-cache \
    && apk add --no-cache \
        ca-certificates \
        libgcc \
        libstdc++ \
        "python3=${PYTHON_APK_VERSION}" \
        "sqlite-libs>=${SQLITE_MIN_VERSION}" \
    && adduser -S -D -h /home/atlassian -s /sbin/nologin atlassian

COPY --from=builder /opt/atlassian /opt/atlassian

RUN apk info -e "python3=${PYTHON_APK_VERSION}" \
    && apk info -v python3 sqlite-libs \
    && python3 -c "import platform; assert platform.python_version() == '${PYTHON_APK_VERSION%-r*}', platform.python_version()" \
    && python3 -c "from importlib.metadata import version; from packaging.version import Version; assert version('mcp-atlassian') == '${ATLASSIAN_VERSION}'; assert version('setuptools') == '${SETUPTOOLS_VERSION}'; assert Version(version('atlassian-python-api')) < Version('5.0.0')" \
    && ! command -v pip \
    && ! command -v pip3 \
    && ! python3 -c "import pip" 2>/dev/null \
    && test -z "$(find / -type f -path '*/pip/_vendor/*' -print -quit 2>/dev/null)" \
    && test -z "$(find / -type f -path '*/ensurepip/_bundled/*' -print -quit 2>/dev/null)" \
    && python3 -c "import sqlite3; from importlib.metadata import distributions; from packaging.version import Version; packages={d.metadata['Name'].lower(): d.version for d in distributions()}; assert sqlite3.sqlite_version_info >= (3, 53, 4); assert 'msgpack' not in packages or Version(packages['msgpack']) >= Version('1.2.1'); import mcp_atlassian" \
    && mcp-atlassian --help >/dev/null

USER atlassian
WORKDIR /home/atlassian

LABEL org.opencontainers.image.title="atlassian-mcp" \
      org.opencontainers.image.description="MCP server for Atlassian Jira and Confluence" \
      org.opencontainers.image.source="https://github.com/sooperset/mcp-atlassian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ATLASSIAN_VERSION}"

ENTRYPOINT ["mcp-atlassian"]

