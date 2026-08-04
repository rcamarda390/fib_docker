# syntax=docker/dockerfile:1.7

FROM python:3.13-slim

ARG BIFROST_VERSION=0.23.0

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN useradd --system --create-home --home-dir /home/bifrost --shell /usr/sbin/nologin bifrost \
    && pip install --no-cache-dir "mcp-atlassian==${BIFROST_VERSION}" \
    && rm -rf /root/.cache

USER bifrost
WORKDIR /home/bifrost

LABEL org.opencontainers.image.title="bifrost-mcp" \
      org.opencontainers.image.description="MCP server for Atlassian Jira and Confluence" \
      org.opencontainers.image.source="https://github.com/sooperset/mcp-atlassian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${BIFROST_VERSION}"

ENTRYPOINT ["mcp-atlassian"]
