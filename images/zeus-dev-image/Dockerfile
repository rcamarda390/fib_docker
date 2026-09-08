# syntax=docker/dockerfile:1.7
# ============================================================
# zeus-dev-image -- public-source build
# ============================================================
# Reproduces the internal zeus-dev-image dev container from public sources
# only (npmjs.org, PyPI, GitHub, Docker Hub, Red Hat Registry). See
# README.md for the internal -> public component mapping and what was
# intentionally omitted.
#
# Build command: docker build --no-cache -t zeus-dev-image:external .
# Run command:   docker run --rm -it zeus-dev-image:external /bin/bash

# ponytail: base image uses the mutable `:latest` tag, matching the internal
# build. Pin to a digest if this image needs to stop tracking upstream UBI9
# security updates automatically.

# ============================================================
# sqz CLI -- built from the same pinned commit already vetted for the
# sqz-mcp image in this repo (images/sqz-mcp). Reuses that image's vendored
# Cargo.lock, which covers the whole cargo workspace (sqz-cli, sqz-engine,
# sqz-mcp), so it applies unchanged here.
# ============================================================
FROM alpine:3.23.4@sha256:5b10f432ef3da1b8d4c7eb6c487f2f5a8f096bc91145e68878dd4a5019afde11 AS sqz-source
ARG SQZ_VERSION=1.3.0
ARG SQZ_COMMIT=d024b6b6bec152dfa7a63e2316054b1bb33a8110
RUN apk add --no-cache ca-certificates git \
    && n=0; until [ "$n" -ge 5 ]; do \
        git clone --depth 1 --branch "v${SQZ_VERSION}" \
            https://github.com/ojuschugh1/sqz.git /src && break; \
        n=$((n + 1)); \
        echo "git clone failed (attempt $n/5), retrying..."; \
        rm -rf /src; \
        sleep $((n * 3)); \
    done \
    && test -d /src \
    && test "$(git -C /src rev-parse HEAD)" = "$SQZ_COMMIT"

FROM rust:1.85-alpine AS sqz-builder
WORKDIR /build
RUN apk add --no-cache musl-dev
COPY --from=sqz-source /src/ .
# See images/sqz-mcp/Dockerfile for why upstream's .cargo/config.toml has to
# go on a musl-alpine host build.
RUN rm -f .cargo/config.toml
COPY Cargo.lock ./Cargo.lock
RUN cargo build --release --locked --package sqz-cli \
    && test -f target/release/sqz \
    && mkdir -p /app \
    && cp target/release/sqz /app/sqz

# ============================================================
# Final image
# ============================================================
FROM registry.access.redhat.com/ubi9/python-311:latest

# This image is a composite dev container, not a build of one upstream
# project, so there is no single "upstream_version" to track. This ARG is
# the version_arg the shared build-image.yml workflow expects; it labels
# the image with the local zeus-dev-image release number from image.yaml.
ARG ZEUS_DEV_IMAGE_VERSION=1.0.0
LABEL org.opencontainers.image.title="zeus-dev-image" \
      org.opencontainers.image.description="Public-source dev container: Airflow, AWS CLI, Cline, Claude Code, AgentMemory MCP, sqz" \
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

# ============================================================
# Add useful shell aliases
# ============================================================
RUN echo "alias ll='ls -alF'" > /etc/profile.d/aliases.sh

# ============================================================
# Install OS packages
# ============================================================
# nodejs:20 module enabled explicitly -- without this, plain `npm`/`nodejs`
# package names resolve to whatever the default module stream is for the
# base image's RHEL9 AppStream, not necessarily 20.x.
RUN dnf -y module enable postgresql:15 \
    && dnf -y module enable nodejs:20 \
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
        v20.*) echo "OK: Node.js 20.x confirmed" ;; \
        *) echo "ERROR: Expected Node.js v20.x, got $(node --version)"; exit 1 ;; \
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
# Extension points for future internal-only components.
# ============================================================
# ponytail: the internal build's generic tarball auto-installer (Python
# wheel / npm tarball / RPM sniffing) was not carried over here -- every
# component it used to handle is now installed explicitly below via its
# public source. If a genuinely internal-only tool (e.g. a confirmed public
# equivalent for "archify", or GitLab server tooling) shows up later, drop
# it in files/ or preload/ and add an explicit install step near the
# component it replaces, rather than reintroducing a generic sniffing loop.
COPY files/ /opt/files/
COPY preload/ /opt/preload/

# ============================================================
# AgentMemory MCP (public npm: @agentmemory/agentmemory)
# ============================================================
# Installed as a local (non-global) npm project under /opt/agentmemory so
# the resulting path /opt/agentmemory/node_modules/@agentmemory/agentmemory/
# dist/index.mjs matches what agentmemory-mcp.sh and Cline's MCP config
# expect.
ARG AGENTMEMORY_VERSION=0.9.29
WORKDIR /opt/agentmemory
RUN printf '{"name":"zeus-dev-agentmemory","version":"1.0.0","private":true}\n' > package.json \
    && npm install "@agentmemory/agentmemory@${AGENTMEMORY_VERSION}" --no-fund --no-audit \
    && test -f node_modules/@agentmemory/agentmemory/dist/index.mjs \
    && echo "OK: AgentMemory MCP ${AGENTMEMORY_VERSION} installed to /opt/agentmemory"
WORKDIR /

# ============================================================
# Cline CLI (public npm: cline)
# ============================================================
ARG CLINE_VERSION=3.0.60
RUN npm install -g "cline@${CLINE_VERSION}" \
    && command -v cline \
    && cline --version

# ============================================================
# Claude Code CLI (public npm: @anthropic-ai/claude-code)
# ============================================================
# Wrapped to unset AWS_PROFILE for Bedrock/IMDS auth (scoped fix - do NOT
# change the global AWS_PROFILE=PDEVELOPER env, other tooling depends on it).
ARG CLAUDE_CODE_VERSION=2.1.252
RUN npm install -g "@anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}" \
    && real_claude="$(command -v claude)" \
    && mv "$real_claude" "${real_claude}.real" \
    && printf '#!/bin/sh\n\nexec env -u AWS_PROFILE "%s.real" "$@"\n' "$real_claude" > "$real_claude" \
    && chmod +x "$real_claude" \
    && claude --version

# ============================================================
# sqz CLI (built from source in the sqz-builder stage above)
# ============================================================
COPY --from=sqz-builder /app/sqz /usr/local/bin/sqz
RUN chmod +x /usr/local/bin/sqz \
    && sqz --version

# ============================================================
# Archify skill / GitLab server tooling
# ============================================================
# Not installed. Neither had a public source that could be confirmed to
# match the pinned internal version (BUILD-MANIFEST.md). Installing an
# unverified same-named package here would be worse than omitting it --
# verify-installation.sh reports both as intentionally skipped rather than
# silently missing.

# ============================================================
# Install Apache Airflow 2.11.0
# ============================================================
# External build uses the standard public PyPI install: the internal
# --no-deps + bundled wheel + --find-links workaround existed only to route
# around an internal repository restriction on apache-airflow-providers-fab,
# which does not apply here.
RUN set -eux; \
    curl -fsSL -o /tmp/constraints-airflow.txt \
        https://raw.githubusercontent.com/apache/airflow/constraints-2.11.0/constraints-3.11.txt; \
    \
    echo "=== Installing Apache Airflow 2.11.0 from public PyPI ==="; \
    pip3 install --no-input --no-cache-dir --constraint /tmp/constraints-airflow.txt \
        apache-airflow==2.11.0; \
    \
    echo "=== Installing Airflow provider packages from public PyPI ==="; \
    pip3 install --no-input --no-cache-dir --constraint /tmp/constraints-airflow.txt \
        apache-airflow-providers-common-compat \
        apache-airflow-providers-common-io \
        apache-airflow-providers-common-sql \
        apache-airflow-providers-ftp \
        apache-airflow-providers-http \
        apache-airflow-providers-imap \
        apache-airflow-providers-smtp \
        apache-airflow-providers-sqlite; \
    \
    echo "=== Installing pinned Airflow provider packages ==="; \
    pip3 install --no-input --no-cache-dir --constraint /tmp/constraints-airflow.txt \
        apache-airflow-providers-amazon \
        apache-airflow-providers-ssh; \
    pip3 install --no-input --no-cache-dir --no-deps \
        apache-airflow-providers-fab==1.5.3; \
    \
    rm -f /tmp/constraints-airflow.txt; \
    echo "=== Apache Airflow 2.11.0 installation complete ==="; \
    installed_version=$(python3 -c "import airflow; print(airflow.__version__)"); \
    echo "Installed Airflow version: $installed_version"; \
    if [ "$installed_version" != "2.11.0" ]; then \
        echo "ERROR: Expected Airflow 2.11.0, got $installed_version"; \
        exit 1; \
    fi; \
    python3 -c "from airflow.providers.fab import __version__; print('FAB version:', __version__)"

# ============================================================
# Python dependencies (pinned versions from BUILD-MANIFEST.md)
# ============================================================
RUN pip3 install --no-input --no-cache-dir --upgrade pip \
    && pip3 install --no-input --no-cache-dir \
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
        markdown-it-py==3.0.0 \
        sqlfluff==4.1.0 \
    && pip3 install --no-input --no-cache-dir \
        botocore==1.43.54 \
        boto3==1.43.54 \
    && pip3 install --no-input --no-cache-dir \
        docutils rsa \
    && pip3 install --no-input --no-cache-dir --no-deps \
        awscli==1.45.12 \
    && aws --version \
    && pip3 install --no-input --no-cache-dir ruff==0.15.11 \
        || echo "WARNING: ruff not available in repository, continuing build" \
    && pip3 install --no-input --no-cache-dir pyfiglet \
        || echo "WARNING: pyfiglet not available in repository, continuing build" \
    && rm -rf /root/.cache /tmp/* /var/tmp/*

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
ENTRYPOINT ["/usr/local/bin/dev-entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
