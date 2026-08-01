# fib_docker contributor instructions

## Repository purpose

This repository builds and publishes versioned Docker images for MCP services:
`agentmemory`, `iii-engine`, and the air-gapped `gnosis-mcp` image. The root
`Dockerfile` is a separate Docker Hub development image and is not an MCP image.

## Required workflow

1. Inspect the relevant workflows, Dockerfiles, image metadata, compose files, and
   existing documentation before editing.
2. Work from the repository default branch (`main`) on a dedicated feature branch.
   Keep changes surgical and do not revert unrelated user changes.
3. Preserve existing image names, registry destinations, tag formats, and manual
   revision ownership unless the task explicitly changes the release contract.
4. Validate the smallest relevant existing checks. At minimum run `git diff --check`;
   run YAML/workflow validation, Docker builds, and targeted smoke or integration
   tests when the required tools and daemon are available.
5. Commit with the repository's required trailer:
   `Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>`.
6. Push the branch and open a non-draft pull request targeting `main` with a concise
   summary, validation results, and explicit blockers or known limitations.

## MCP image release contract

- `images/*/image.yaml` is the source of truth for the image name, upstream version,
  revision, build arguments, and registry publication flags.
- Increment `revision` deliberately when changing an image build or runtime patch.
- MCP tags use `<upstream_version>-v<revision>` and publish to both GHCR and Docker
  Hub. MCP images do not publish `latest`.
- The reusable `.github/workflows/build-image.yml` workflow must keep registry
  credentials and permissions least-privilege. Callers must grant `contents: read`
  and `packages: write`; Docker Hub uses `vars.DOCKERHUB_USERNAME` and
  `secrets.DOCKERHUB_TOKEN`.
- MCP candidate validation must happen before final registry publication. Prefer
  deterministic, offline-capable startup and protocol checks; do not make CI depend
  on unbounded network access or external services.
- Keep single-image smoke checks distinct from compose-level integration checks so
  failures identify the broken layer.

## Security and policy exceptions

- Keep Trivy visible and reporting. Do not weaken, bypass, or hide findings, including
  stale-version findings that are known scanner or SBOM accuracy issues.
- The root image workflow intentionally publishes its root image even when Trivy
  reports vulnerabilities. Do not remove its `if: always()` publication policy
  without an explicit product decision.
- Do not add pip or npm Dependabot ecosystems unless the repository contains valid
  manifests or lockfiles for those ecosystems.
- Do not add optional Cosign signing, multi-architecture expansion, non-root runtime
  changes, action SHA pinning, base-image digest pinning, or SBOM/provenance changes
  to a scoped CI-hardening change unless explicitly requested or required.

## Candidate evaluation direction

The preferred evaluation sequence is: build candidate, start container, verify
readiness/health, perform an MCP transport and JSON-RPC initialization probe, run a
small deterministic tool or resource check, tear down, then publish. Use bounded
timeouts and resource limits. A health endpoint alone is not sufficient evidence
that MCP initialization or dependent-service connectivity works.

See `docs/MCP_BUILD_METHODOLOGY.md` and
`images/agentmemory-mcp/CUSTOMIZATION.md` for the current release procedures.
