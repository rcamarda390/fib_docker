# zeus-dev-image

Public-source rebuild of the internal `zeus-dev-image` dev container. Every
component is installed from a public registry (npmjs.org, PyPI, GitHub,
Docker Hub, Red Hat Registry) -- there is no dependency on an internal
repository or Artifactory mirror.

## What's in it

- Base: `registry.access.redhat.com/ubi9/python-311:latest`
- Runtimes: Python 3.11, Node.js 20, PostgreSQL 15 client
- Apache Airflow `2.11.0` with the FTP/HTTP/IMAP/SMTP/SQLite/common/Amazon/
  SSH/FAB providers, installed straight from public PyPI against the
  official Airflow constraints file for that release
- AWS CLI `1.45.12`, boto3/botocore `1.43.54`
- `cline` CLI `3.0.60` (npm)
- `@anthropic-ai/claude-code` CLI `2.1.252` (npm), wrapped to unset
  `AWS_PROFILE` for Bedrock/IMDS auth without touching the global
  `AWS_PROFILE=PDEVELOPER` other tooling depends on
- AgentMemory MCP `0.9.29` (`@agentmemory/agentmemory` on npm), installed
  under `/opt/agentmemory` so its entry point matches Cline's
  `cline_mcp_settings.json` and `agentmemory-mcp.sh`
- `sqz` CLI `1.3.0`, built from source at the same commit already pinned by
  `images/sqz-mcp` in this repo (`SQZ_COMMIT` in `image.yaml`)
- Dev tools: pyright, ruff, sqlfluff, pyfiglet, jira/jirashell

## Intentionally omitted

Two components from the internal build have no confirmed public equivalent
and are **not installed**:

- **Archify skill** (`archify-2.17.0-dev.1-*.tar.gz`) -- a public package
  named `archify` exists, but its versioning and purpose (an agent skill
  for architecture diagrams) don't line up with the internal pin, so it was
  not assumed to be the same tool.
- **GitLab server tooling** (`gitlab-server-node-modules.tar.gz`) -- no
  public equivalent found; likely internal-only.

`verify-installation.sh` reports both as intentionally skipped. If a public
source is confirmed for either later, drop the tarball/package reference
into `files/` or `preload/` and add an explicit install step next to the
component it replaces -- see the "Extension points" comment in the
Dockerfile.

## Differences from the internal build

- Public npm/PyPI registries instead of an internal Artifactory mirror
- Public Docker CE repo instead of an internal mirror
- Airflow installed directly from PyPI (no `--no-deps` + bundled-wheel
  workaround -- that only existed to route around an internal repository
  restriction on `apache-airflow-providers-fab`)
- `files/` and `preload/` ship empty; they're drop-in points for whatever
  gets resolved for the two omitted components above

## Build

```bash
docker build --no-cache -t zeus-dev-image:external .
docker run --rm -it zeus-dev-image:external /bin/bash
```

`BUILD_MODE=production` makes the in-build verification step
(`verify-installation.sh --prod`) fail the build if a required tool is
missing; the default `test` mode only warns.

## Verify

```bash
docker run --rm zeus-dev-image:external /usr/local/bin/verify-installation.sh --prod
```

## Release

`image.yaml` is the source of truth for the published tag
(`<upstream_version>-v<revision>`). There is no single upstream project to
track for this composite image, so `upstream_version` is a local counter
(`1.0.0`) rather than a tracked project release, and
`.github/workflows/build-zeus-dev-image.yml` auto-increments `revision` on
every publish, same as `sqz-mcp`.
