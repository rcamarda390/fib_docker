# zeus-dev-image

Base image candidate for `artifactory.<redacted>/beds-docker/beds-ubi9-python3.11`.
Built here (public GitHub Actions, GHCR/Docker Hub) because that base is on
an air-gapped internal artifactory unreachable from a hosted runner. The
flow is:

1. Dispatch `build-zeus-dev-image.yml` to build and publish a candidate
   here.
2. Import the candidate into your artifactory and run Xray against it.
3. If it passes, it replaces `beds-ubi9-python3.11` as the base for your
   downstream image.

This image installs its tools from public upstream sources during the GitHub
Actions build. It does not copy or retain the air-gapped `files/` or
`preload/` artifact directories.

## What's in it

- Base: `registry.access.redhat.com/ubi9/python-311:latest`
- Runtimes: Python 3.11, Node.js 22, PostgreSQL 15 client
- `xdg-user-dir` from upstream xdg-user-dirs `0.20`, pinned to commit
  `cd05b6d29da1abdb3cd253ef496ae7fd1593e4bb`
- Apache Airflow `2.11.0`, installed with the official Python 3.11
  constraints and the FTP/HTTP/IMAP/SMTP/SQLite/common/Amazon/SSH/FAB
  providers from PyPI
- AWS CLI `1.45.12`, boto3/botocore `1.43.54`
- AgentMemory `0.9.29` from npm (`@agentmemory/agentmemory` and `@agentmemory/mcp`)
- Cline CLI `3.0.61` from npm
- Claude Code CLI `2.1.252` from npm
- SQLFluff `4.1.0` from PyPI
- Archify `2.17.0-dev.1` from the pinned upstream commit
- GitLab MCP Node.js dependencies installed under `/opt/gitlab-mcp-server/node_modules`
- Archify CLI is installed at `/opt/archify` from `tt-a1i/archify` commit
  `06dd052602dd9a369e4d034e24faef0917b5a60c` (version `2.17.0-dev.1`).
  This exact commit matches the verified internal filename
  `archify-2.17.0-dev.1-06dd052602dd.tar.gz`.
- `claude` is wrapped to unset `AWS_PROFILE` for Bedrock/IMDS auth without
  changing the global environment for other tooling

## Intentionally skipped

- `sqz` -- intentionally excluded from this external image.
- VS Code extension packages -- this is a headless base image.

## Untouched

Users/groups, Docker CLI, unzip, `agentmemory-mcp.sh`, `jirashell.sh`,
`new_prompt.sh`, `dev-entrypoint.sh`, `verify-installation.sh`, and the
dnf package list are unchanged from before this base-image rework and are
owned by your existing downstream build, not this task.

## Build

```bash
docker build --no-cache -t zeus-dev-image:external .
docker run --rm -it zeus-dev-image:external /bin/bash
```

`BUILD_MODE=production` makes the in-build verification step
(`verify-installation.sh --prod`) fail the build if a required tool is
missing; the default `test` mode only warns. `verify-installation.sh`
still lists `sqz`/`cline`/`claude`/etc. as "required" (it wasn't changed
as part of this rework), so it'll warn about `sqz` even though it's
intentionally skipped -- non-blocking in the default `test` mode.

## Release

`image.yaml` is the source of truth for the published tag
(`<upstream_version>-v<revision>`). There is no single upstream project to
track for this composite image, so `upstream_version` is a local counter
(`1.0.0`) rather than a tracked project release, and
`.github/workflows/build-zeus-dev-image.yml` auto-increments `revision` on
every publish, same as `sqz-mcp`.
