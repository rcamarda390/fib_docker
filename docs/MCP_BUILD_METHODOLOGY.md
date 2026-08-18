# MCP image build methodology

The MCP images built by this repository are published with the same versioned
tag in both registries:

- `ghcr.io/rcamarda390/<image>:<upstream-version>-v<revision>`
- `docker.io/rcamarda390/<image>:<upstream-version>-v<revision>`

The current images are `agentmemory`, `gnosis-mcp`, `atlassian-mcp`,
`bifrost-mcp`, `headroom-mcp`, and `sqz-mcp`. Their metadata is human-edited
in `images/<image-dir>/image.yaml`. Published MCP builds automatically
increment and commit the image revision. When `upstream_version` changes, the
revision resets to `1`; pull request validation builds do not consume
revisions. Image-specific Docker build arguments are also defined there.

`agentmemory` is built from `images/agentmemory-server/`: agentmemory and its
compatible `iii` engine binary are bundled into one image, there is no
separate `iii-engine` image or workflow. `images/agentmemory-server/image.yaml`'s
`build_args.III_VERSION` tracks the exact iii version agentmemory's own
`iii-sdk` dependency pins — it is not bumped independently just because a
newer `iii-hq/iii` release exists. See
[`images/agentmemory-server/README.md`](../images/agentmemory-server/README.md)
for the full architecture and update procedure.

The `sqz-mcp` build vendors `images/sqz-mcp/Cargo.lock` because its upstream
repository does not commit a lockfile. Regenerate that lockfile with
`cargo generate-lockfile` whenever `SQZ_VERSION` changes.

Image builds are manual: each image caller workflow is triggered only with
`workflow_dispatch`, so merges, pull requests, and scheduled runs do not build
or publish images. Run the workflow for the image you want to build.

`gnosis-mcp` currently means the air-gap build: its ONNX embedding model is
pre-bundled and the image is labeled with `gnosis.airgap=true`. The air-gap
variant is not represented by a tag suffix. MCP workflows publish versioned
tags only and do not publish `latest`, `latest-airgap`, or `-build-*` tags.

Each image has an individual caller workflow. The shared
`.github/workflows/build-image.yml` workflow owns checkout, metadata parsing,
GHCR authentication with `GITHUB_TOKEN`, Docker Hub authentication with
`vars.DOCKERHUB_USERNAME` and `secrets.DOCKERHUB_TOKEN`, and dual publishing.
Image-specific smoke tests remain in the caller workflows. Gnosis candidates
are also scanned with Trivy for HIGH and CRITICAL vulnerabilities, including
unfixed findings, before any registry login or publication. Scan findings are
reported but do not block publication; external image scanning tools provide
additional security review.

The non-MCP `.github/workflows/dockerhub.yml` workflow builds the repository
root `Dockerfile` and remains outside this MCP standardization.

## Triaging scanner findings against Debian base images

Xray and Trivy report a CVE when the *package version* falls in the affected
range. Debian backports fixes without changing upstream version numbers, and it
also declines to fix issues it considers minor, so a finding needs to be checked
against the Debian security tracker before it is treated as either real or
false. Record the outcome in the Dockerfile next to the package it concerns.

Three outcomes are possible, and they need different responses:

1. **Not applicable to Debian's build.** The vulnerable code is not compiled in.
   Example: `zlib1g` CVE-2023-45853 (CVSS 9.8) is MiniZip only, which Debian
   does not build in bookworm's `zlib1g`; the tracker marks it `<ignored>`.
   Nothing to do but document it — the finding is noise.
2. **Real but unfixable in this suite.** Debian marks it `<no-dsa>`
   ("Minor issue") with no fixed version, so `apt-get upgrade` can never clear
   it. Example: `libsqlite3-0` CVE-2025-7458 and `libc-bin` CVE-2026-5450, both
   of which are also still unfixed in trixie. Document the reachability
   argument; only a base-image move or a vendored build actually clears it.
3. **Genuinely fixed upstream in a newer suite.** Then it is a deliberate
   base-image decision, not a purge.

### Purging a package is a functional change, not a scanner tweak

Purging is only valid when nothing in the image uses the package. Check before
purging, and never infer it from an assumption about static linking:

    docker run --rm <base> apt-cache rdepends --installed <pkg>
    docker run --rm <base> ldd /usr/local/lib/python3.13/lib-dynload/<mod>.so

`libsqlite3-0` was purged from `headroom-mcp` on the theory that Python bundles
SQLite statically. It does not: `_sqlite3.cpython-313-*.so` links
`libsqlite3.so.0` dynamically, and the published image died at startup with
`ImportError: libsqlite3.so.0: cannot open shared object file`. The same false
premise was still recorded for `zlib1g`, which Python's `zlib` module also links
dynamically.

### Make the build fail where the mistake is made

That purge passed a build-time check of `python -c "import sys; sys.exit(0)"`,
which cannot detect a missing shared library. The runtime stage now imports the
stdlib modules whose backing libraries a purge could remove and exercises
`sqlite3` and `ssl`, so a bad purge fails in the layer that caused it instead of
surfacing later as an opaque MCP startup error. Guards must also be falsifiable:
`! command -v ncurses` never fails, because no `ncurses` binary exists in any
image — `ncurses-bin` ships `tput`, which is what the check now tests.
