# syntax=docker/dockerfile:1.7
# ============================================================
# zeus-dev-image -- base image candidate
# ============================================================
# Builds a UBI9/Python 3.11 base image and installs additional tooling from
# public upstream sources (AgentMemory, Cline, Claude Code,
# Archify, Airflow, SQLFluff, and GitLab MCP dependencies). Built here
# (public GitHub Actions) because the real target
# base -- artifactory.<redacted>/beds-docker/beds-ubi9-python3.11 -- is
# air-gapped and unreachable from this runner. You import the published
# candidate into artifactory yourself, Xray it, and promote it to replace
# that base image if it passes.
#
# sqz and cline-*.vsix are intentionally skipped -- see README.md.
#
# Everything else (users, entrypoint, jirashell/new_prompt/verify-
# installation/agentmemory-mcp scripts) is untouched; that stays with your
# existing downstream build.
#
# Build command: docker build --no-cache -t zeus-dev-image:external .
# Run command:   docker run --rm -it zeus-dev-image:external /bin/bash

# ============================================================
# Archify CLI source -- fetch the exact commit without carrying Git metadata
# into the final image.
# ============================================================
ARG ARCHIFY_COMMIT=06dd052602dd9a369e4d034e24faef0917b5a60c
FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e688dd4a5019afde11 AS archify-source
ARG ARCHIFY_COMMIT
RUN apk add --no-cache ca-certificates git \
    && git init /src \
    && git -C /src remote add origin https://github.com/tt-a1i/archify.git \
    && n=0; until [ "$n" -ge 5 ]; do \
        git -C /src fetch --depth 1 origin "$ARCHIFY_COMMIT" \
            && git -C /src checkout --detach FETCH_HEAD && break; \
        n=$((n + 1)); \
        echo "git fetch failed (attempt $n/5), retrying..."; \
        sleep $((n * 3)); \
    done \
    && test "$(git -C /src rev-parse HEAD)" = "$ARCHIFY_COMMIT"

# ============================================================
# Final image
# ============================================================
# ponytail: base image uses the mutable `:latest` tag, matching the internal
# build. Pin to a digest if this image needs to stop tracking upstream UBI9
# security updates automatically.
FROM registry.access.redhat.com/ubi9/python-311:latest

# The UBI base defaults to UID 1001. Build layers need root to install OS
# packages and write under /etc, /opt, and /usr/local.
USER 0

# This image is a composite base image, not a build of one upstream
# project, so there is no single "upstream_version" to track. This ARG is
# the version_arg the shared build-image.yml workflow expects; it labels
# the image with the local zeus-dev-image release number from image.yaml.
ARG ZEUS_DEV_IMAGE_VERSION=1.0.0
LABEL org.opencontainers.image.title="zeus-dev-image" \
      org.opencontainers.image.description="UBI9/Python 3.11 base image candidate: Airflow, AWS CLI, Cline, Claude Code, AgentMemory MCP" \
      org.opencontainers.image.version="${ZEUS_DEV_IMAGE_VERSION}"

# ============================================================
# Build mode (test|production) - controls whether the final
# installation verification step fails the build on missing
# required software. Defaults to "test" (safe) when built
# directly with `docker build` without --build-arg BUILD_MODE.
# ============================================================
ARG BUILD_MODE=test

# ============================================================
# Airflow runtime directories
# ============================================================
ENV AIRFLOW_HOME=/opt/airflow
ENV ARCHIFY_UPDATE_CHECK_DISABLED=1

# ============================================================
# Install OS packages
# ============================================================
# nodejs:22 module enabled explicitly -- without this, plain `npm`/`nodejs`
# package names resolve to whatever the default module stream is for the
# base image's RHEL9 AppStream, not necessarily 22.x.
RUN dnf -y module enable postgresql:15 \
    && dnf -y module enable nodejs:22 \
    && dnf install -y \
        vim \
        vi \
        shadow-utils \
        findutils \
        file \
        hostname \
        procps-ng \
        nodejs \
        npm \
        git \
        jq \
        tar \
        postgresql \
        xdg-user-dirs \
    && dnf clean all \
    && rm -rf /var/cache/dnf /var/cache/yum /tmp/* /var/tmp/* \
    && echo "=== Verifying Node.js version ===" \
    && node --version \
    && npm --version \
    && case "$(node --version)" in \
        v22.*) echo "OK: Node.js 22.x confirmed" ;; \
        *) echo "ERROR: Expected Node.js v22.x, got $(node --version)"; exit 1 ;; \
    esac

# ============================================================
# Optional convenience packages (not in every UBI9 AppStream/BaseOS repo
# set without extra repos enabled - continue on failure like Docker CLI
# and unzip below).
# ============================================================
RUN dnf install -y htop btop \
    || echo "WARNING: htop/btop not available in repository, continuing build"

# ============================================================
# AgentMemory MCP wrapper script
# ============================================================
# Only referenced at container runtime, so it is safe to install here even
# though /opt/agentmemory doesn't exist yet at this point in the build.
COPY agentmemory-mcp.sh /usr/local/bin/agentmemory-mcp.sh
RUN chmod +x /usr/local/bin/agentmemory-mcp.sh

# ============================================================
# Install Docker CLI (optional - continues on failure)
# ============================================================
# Base image uses microdnf which doesn't support config-manager.
# Create repo file directly instead.
RUN set -e; \
    echo "=== Installing Docker CLI ==="; \
    echo '[docker-ce-stable]' > /etc/yum.repos.d/docker-ce.repo; \
    echo 'name=Docker CE Stable - $basearch' >> /etc/yum.repos.d/docker-ce.repo; \
    echo 'baseurl=https://download.docker.com/linux/rhel/9/$basearch/stable' >> /etc/yum.repos.d/docker-ce.repo; \
    echo 'enabled=1' >> /etc/yum.repos.d/docker-ce.repo; \
    echo 'gpgcheck=0' >> /etc/yum.repos.d/docker-ce.repo; \
    echo 'repo_gpgcheck=0' >> /etc/yum.repos.d/docker-ce.repo; \
    if dnf install -y docker-ce-cli; then \
        echo "Docker CLI installed successfully"; \
        docker --version; \
    else \
        echo "WARNING: Docker CLI installation failed; continuing without it"; \
    fi; \
    dnf clean all

# ============================================================
# Install unzip (optional - continues on failure)
# ============================================================
RUN dnf install -y unzip-6.0-60.el9 \
    || echo "WARNING: unzip-6.0-60.el9 not available in repository, continuing build"

# ============================================================
# Create developer groups and users, and .ssh directories
# Single source of truth: username:uid:group
# To add a developer, add one line to the $users list below.
# ============================================================
RUN set -eux; \
    getent group dev      >/dev/null 2>&1 || groupadd -g 1003 dev; \
    getent group ec2-user >/dev/null 2>&1 || groupadd -g 1000 ec2-user; \
    \
    users=" \
        srjohnson9:1032:dev \
        cfarias:1027:dev \
        nlombardi:1026:dev \
        koacheampong:1045:dev \
        lsimpson:1056:dev \
        sadugassa:1021:dev \
        aftebeje:1037:dev \
        hmbonda:1019:dev \
        racamarda:1033:dev \
        jleichty:1018:dev \
        pvuong:1017:dev \
        jpkrieger:1025:dev \
        lrichardson3:1047:dev \
        cchao:1050:dev \
        csearles:1058:dev \
        demeadows:1051:dev \
        sklian:1055:dev \
        ojabulefon:1057:dev \
        ec2-user:1000:ec2-user \
    "; \
    \
    for entry in $users; do \
        uname=$(echo "$entry" | cut -d: -f1); \
        uid=$(echo "$entry"   | cut -d: -f2); \
        grp=$(echo "$entry"   | cut -d: -f3); \
        \
        id -u "$uname" >/dev/null 2>&1 \
            || useradd -m -u "$uid" -g "$grp" -s /bin/bash "$uname"; \
        \
        mkdir -p /home/$uname/.ssh; \
        chown $uname:$grp /home/$uname/.ssh; \
        chmod 700 /home/$uname/.ssh; \
        \
        mkdir -p /home/$uname/.local/bin; \
        ln -sf /bin/python3 /home/$uname/.local/bin/python; \
        chown -R $uname:$grp /home/$uname/.local; \
    done

# ============================================================
# npm registry: default npmjs.org (no configuration needed)
# ============================================================

# ============================================================
# Optional: Pyright for Python type checking (dev tool only)
# ============================================================
RUN npm install -g pyright \
    || echo "WARNING: pyright not available in registry, continuing build"

# ============================================================
# Source-installed tools
# ============================================================

# ============================================================
# Apache Airflow 2.11.0 from public PyPI, constrained for Python 3.11.
# ============================================================
RUN set -eux; \
    CONSTRAINTS=/tmp/constraints-airflow.txt; \
    curl -fsSL -o "$CONSTRAINTS" \
        https://raw.githubusercontent.com/apache/airflow/constraints-2.11.0/constraints-3.11.txt; \
    pip3 install --no-input --no-cache-dir --constraint "$CONSTRAINTS" apache-airflow==2.11.0; \
    pip3 install --no-input --no-cache-dir --constraint "$CONSTRAINTS" \
        apache-airflow-providers-common-compat \
        apache-airflow-providers-common-io \
        apache-airflow-providers-common-sql \
        apache-airflow-providers-ftp \
        apache-airflow-providers-http \
        apache-airflow-providers-imap \
        apache-airflow-providers-smtp \
        apache-airflow-providers-sqlite \
        apache-airflow-providers-amazon \
        apache-airflow-providers-ssh; \
    pip3 install --no-input --no-cache-dir --no-deps apache-airflow-providers-fab==1.5.3; \
    rm -f "$CONSTRAINTS"; \
    installed_version=$(python3 -c "import airflow; print(airflow.__version__)"); \
    test "$installed_version" = "2.11.0"; \
    python3 -c "from airflow.providers.fab import __version__; print('FAB version:', __version__)"
# ============================================================
# Python dependencies
# ============================================================
RUN set -eux; \
    pip3 install --no-input --no-cache-dir --upgrade pip; \
    pip3 install --no-input --no-cache-dir \
        numpy==1.26.4 \
        pandas==2.2.3 \
        psycopg2-binary==2.9.11 \
        tabulate==0.10.0 \
        sqlparse==0.5.5 \
        cryptography==49.0.0 \
        colorama==0.4.6 \
        PyYAML==6.0.2 \
        duckdb==1.5.3 \
        sqlglot==30.4.2 \
        s3fs==2026.3.0 \
        jira==3.10.5 \
        beautifulsoup4==4.15.0 \
        html2text==2025.4.15 \
        markdown-it-py==3.0.0; \
    \
    pip3 install --no-input --no-cache-dir sqlfluff==4.1.0; \
    \
    pip3 install --no-input --no-cache-dir \
        botocore==1.43.54 \
        boto3==1.43.54; \
    pip3 install --no-input --no-cache-dir docutils rsa; \
    pip3 install --no-input --no-cache-dir --no-deps awscli==1.45.12; \
    aws --version; \
    pip3 install --no-input --no-cache-dir ruff==0.15.11 \
        || echo "WARNING: ruff not available in repository, continuing build"; \
    pip3 install --no-input --no-cache-dir pyfiglet \
        || echo "WARNING: pyfiglet not available in repository, continuing build"; \
    rm -rf /root/.cache /tmp/* /var/tmp/*

# ============================================================
# Source-installed Node.js tools
# ============================================================
# Install packages directly from their public npm sources. The internal
# air-gapped Dockerfile consumes the resulting commands and paths; it does
# not need the original artifact files.
RUN set -eux; \
    npm install --prefix /opt/agentmemory @agentmemory/agentmemory@0.9.29; \
    npm install --prefix /opt/agentmemory-mcp --omit=dev @agentmemory/mcp@0.9.29; \
    ln -sf /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory; \
    ln -sf /opt/agentmemory-mcp/node_modules/@agentmemory/mcp/bin.mjs /usr/local/bin/agentmemory-mcp; \
    npm install -g cline@3.0.60; \
    npm install -g @anthropic-ai/claude-code@2.1.252; \
    cline --version; \
    claude --version

# ============================================================
# GitLab MCP server dependencies
# ============================================================
# Recreate the node_modules bundle described by the internal build:
# @modelcontextprotocol/sdk, axios, TypeScript, and Node.js types.
RUN set -eux; \
    npm install --prefix /opt/gitlab-mcp-server --legacy-peer-deps \
        @modelcontextprotocol/sdk@1.29.0 \
        axios@1.16.0 \
        @types/node \
        typescript; \
    test -d /opt/gitlab-mcp-server/node_modules/@modelcontextprotocol/sdk; \
    test -d /opt/gitlab-mcp-server/node_modules/axios; \
    test -x /opt/gitlab-mcp-server/node_modules/.bin/tsc

# ============================================================
# Archify CLI (vendored from the pinned upstream commit)
# ============================================================
COPY --from=archify-source /src/archify/ /opt/archify/
RUN ln -sf /opt/archify/bin/archify.mjs /usr/local/bin/archify \
    && chmod +x /opt/archify/bin/archify.mjs \
    && archify --help >/dev/null \
    && archify_version="$(node -p "require('/opt/archify/package.json').version")" \
    && echo "Archify version: ${archify_version}" \
    && test "${archify_version}" = "2.17.0-dev.1"

# ============================================================
# Claude Code wrapper: unset AWS_PROFILE for Bedrock/IMDS auth without
# changing the global AWS_PROFILE other tooling depends on.
# ============================================================
RUN set -eux; \
    real_claude="$(command -v claude)"; \
    mv "$real_claude" "${real_claude}.real"; \
    printf '#!/bin/sh\n\nexec env -u AWS_PROFILE "%s.real" "$@"\n' "$real_claude" > "$real_claude"; \
    chmod +x "$real_claude"; \
    claude --version

# ============================================================
# Install jirashell CLI wrapper
# ============================================================
COPY jirashell.sh /usr/local/bin/jirashell
RUN chmod 755 /usr/local/bin/jirashell

# ============================================================
# Airflow directory structure and permissions
# ============================================================
RUN mkdir -p /opt/airflow/logs /opt/airflow/dags /opt/airflow/plugins /opt/airflow/config \
    && chgrp -R dev /opt/airflow \
    && chmod 2775 /opt/airflow \
    && chmod -R g+rwX /opt/airflow \
    && find /opt/airflow -type d -exec chmod g+s {} \;

# ============================================================
# Shared host-tmp directory
# ============================================================
RUN mkdir -p /host-tmp \
    && chmod 1777 /host-tmp \
    && chown root:root /host-tmp

# ============================================================
# Ensure /tmp is world-writable with the sticky bit set (1777). The base
# image is pulled via a mutable ":latest" tag and has shipped /tmp as 755
# root:root before; pin the permission explicitly so this container never
# depends on whatever the base image currently ships.
# ============================================================
RUN chmod 1777 /tmp

# ============================================================
# Copy new_prompt.sh for custom shell prompt
# ============================================================
COPY new_prompt.sh /usr/local/share/new_prompt.sh
RUN chmod 644 /usr/local/share/new_prompt.sh

# ============================================================
# Entrypoint
# ============================================================
COPY dev-entrypoint.sh /usr/local/bin/dev-entrypoint.sh
RUN chmod 755 /usr/local/bin/dev-entrypoint.sh

# ============================================================
# Installation Verification
# ============================================================
COPY verify-installation.sh /usr/local/bin/verify-installation.sh
RUN chmod 755 /usr/local/bin/verify-installation.sh \
    && echo "" \
    && echo "================================================================================" \
    && echo "RUNNING INSTALLATION VERIFICATION (mode: ${BUILD_MODE})" \
    && echo "================================================================================" \
    && if [ "${BUILD_MODE}" = "production" ]; then \
        /usr/local/bin/verify-installation.sh --prod; \
    else \
        /usr/local/bin/verify-installation.sh; \
    fi \
    && echo "" \
    && echo "Installation verification completed" \
    && cat /tmp/installation-verification-report.txt

# ============================================================
# Exposed Ports
# ============================================================
# PostgreSQL connection forwarding (local port 5433)
EXPOSE 5433
# Redshift connection forwarding (local port 5439)
EXPOSE 5439

# ============================================================
# Default workdir and entrypoint
# ============================================================
WORKDIR /opt/airflow
USER 1001
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
