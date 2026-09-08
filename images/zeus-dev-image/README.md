# zeus-dev-image

Base image candidate for `artifactory.<redacted>/beds-docker/beds-ubi9-python3.11`.
Built here (public GitHub Actions, GHCR/Docker Hub) because that base is on
an air-gapped internal artifactory unreachable from a hosted runner. The
flow is:

1. Populate `files/` (and `preload/` if needed) with the tarballs/wheels
   your `build_image.sh` process produces.
2. Dispatch `build-zeus-dev-image.yml` to build and publish a candidate
   here.
3. Import the candidate into your artifactory and run Xray against it.
4. If it passes, it replaces `beds-ubi9-python3.11` as the base for your
   downstream image.

`files/` and `preload/` ship empty in this repo -- this repo's own CI run
builds with nothing in them, which is a structural sanity check only (does
the Dockerfile still build, does Airflow/sqlfluff fall back to PyPI
correctly), not the artifact you'd actually promote.

## What's in it

- Base: `registry.access.redhat.com/ubi9/python-311:latest`
- Runtimes: Python 3.11, Node.js 20, PostgreSQL 15 client
- Apache Airflow `2.11.0` installed from `files/apache_airflow-2.11.0-py3-none-any.whl`
  (constrained by `files/constraints-airflow.txt`) plus the FTP/HTTP/IMAP/
  SMTP/SQLite/common/Amazon/SSH/FAB providers from public PyPI
- `sqlfluff` from `files/sqlfluff-4.1.0-py3-none-any.whl`
- AWS CLI `1.45.12`, boto3/botocore `1.43.54`
- Everything else in `files/` (`agentmemory-mcp-*.tar.gz`, `cline-*.tar.gz`,
  `claude-code-*.tar.gz`, `archify-*.tar.gz`,
  `gitlab-server-node-modules.tar.gz`) installed by the generic tarball
  step: Node.js packages merge into `/opt/node_modules` with `.bin/*`
  symlinked onto `PATH`; other tarballs extract flat into `/opt` with any
  top-level executables symlinked onto `PATH`.
  `agentmemory-mcp-*.tar.gz` is a special case -- extracted straight into
  `/opt/agentmemory/` so the resulting
  `/opt/agentmemory/node_modules/@agentmemory/agentmemory/dist/index.mjs`
  path matches what `agentmemory-mcp.sh` and Cline's MCP config expect.
- `claude` gets wrapped to unset `AWS_PROFILE` for Bedrock/IMDS auth if
  `/opt/claude` exists after extraction (scoped fix -- does not touch the
  global `AWS_PROFILE=PDEVELOPER` other tooling depends on)

Airflow and sqlfluff fall back to public PyPI when their wheel isn't
present in `files/` (only relevant to this repo's own empty-`files/`
sanity build).

## Intentionally skipped

- **`sqz-*.tar.gz`** -- not used, per instruction.
- **`cline-*.vsix`** -- a VS Code extension package; this is a headless
  image with no VS Code Server, so it doesn't belong here. Install it
  through whatever devcontainer/VS Code Server flow already handles
  extensions, not this image.
- **`airflow-2.11.0-py3.11.tar.gz`** -- redundant with the wheel; the wheel
  is the one that gets installed.

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
