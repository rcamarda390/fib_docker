# syntax=docker/dockerfile:1.7

FROM python:3.16-alpine

ARG ATLASSIAN_VERSION=0.23.0

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN adduser -S -D -h /home/atlassian -s /sbin/nologin atlassian \
    && pip install --no-cache-dir --upgrade setuptools \
    && pip install --no-cache-dir "mcp-atlassian==${ATLASSIAN_VERSION}" \
    && rm -rf /root/.cache

USER atlassian
WORKDIR /home/atlassian

LABEL org.opencontainers.image.title="atlassian-mcp" \
      org.opencontainers.image.description="MCP server for Atlassian Jira and Confluence" \
      org.opencontainers.image.source="https://github.com/sooperset/mcp-atlassian" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${ATLASSIAN_VERSION}"

ENTRYPOINT ["mcp-atlassian"]
