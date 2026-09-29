# Project URLs and upstream review

This repository: https://github.com/rcamarda390/fib_docker

Use this index to resolve image names to their source projects. The checked-in `images/<image>/image.yaml` and Dockerfile remain authoritative for the version, commit, dependencies, and build behavior. Verify URLs against upstream when using them; do not infer a release from a documentation site's version selector.

| Image directory | Primary upstream source | Release or package page | Notes |
| --- | --- | --- | --- |
| `agentmemory-server` | https://github.com/rohitg00/agentmemory | https://github.com/rohitg00/agentmemory/releases | Also bundles compatible iii engine: https://github.com/iii-hq/iii. Check its compatibility with AgentMemory, not independently by newest tag. |
| `atlassian-mcp` | https://github.com/sooperset/mcp-atlassian | https://github.com/sooperset/mcp-atlassian/releases | Separate image from `sooperset-mcp-atlassian`. |
| `bifrost-mcp` | https://github.com/maximhq/bifrost | https://github.com/maximhq/bifrost/releases | Release tags use `transports/v<version>`. |
| `docker-socket-proxy` | https://github.com/Tecnativa/docker-socket-proxy | https://github.com/Tecnativa/docker-socket-proxy/releases | Also check HAProxy version and digest in the manifest. |
| `ebay-mcp` | https://github.com/YosefHayim/ebay-mcp | https://github.com/YosefHayim/ebay-mcp/releases | Source tag and commit are pinned. |
| `gnosis-mcp` | https://github.com/nicholasglazer/gnosis-mcp | https://pypi.org/project/gnosis-mcp/ | Package release is the version source; GitHub releases may differ. |
| `headroom-mcp` | https://github.com/headroomlabs-ai/headroom | https://github.com/headroomlabs-ai/headroom/releases | Also check downstream LiteLLM and security pins. |
| `litellm` | https://github.com/BerriAI/litellm | https://github.com/BerriAI/litellm/releases | Image's own LiteLLM release. |
| `nginx` | https://github.com/nginx/nginx | https://github.com/nginx/nginx/releases | Check the `release-<version>` tag used by the Dockerfile. |
| `sooperset-mcp-atlassian` | https://github.com/sooperset/mcp-atlassian | https://pypi.org/project/mcp-atlassian/ | Documentation: https://mcp-atlassian.soomiles.com. Distinct downstream build from `atlassian-mcp`. |
| `sqz-mcp` | https://github.com/ojuschugh1/sqz | https://github.com/ojuschugh1/sqz/releases | Vendored Cargo.lock must follow upstream. |
| `zeus-dev-image` | Composite image | See `images/zeus-dev-image/Dockerfile` and README | No single upstream version. Check each installed product and its source; pinned Archify: https://github.com/tt-a1i/archify; xdg-user-dirs: https://gitlab.freedesktop.org/xdg/xdg-user-dirs. |

## Check every image for updates

When asked for a repository-wide update review, enumerate the directories under `images/` from the current default branch and account for every image, including new directories not yet in this table. For each, read its `image.yaml`, Dockerfile, relevant lockfile, image-specific README, and build workflow. Compare the pinned application release with the latest applicable stable upstream release or package version. For composite images, compare each installed upstream component; for bundled dependencies that are compatibility-coupled, check supported versions together.

Report one row per image with current version, latest applicable version, source URL, status (update available, current, blocked, or unable to verify), and any compatibility/security/build caveat. Include the checked date and distinguish latest tag from latest stable release. Review release notes, dependency changes, local patches, and migration/persistence risks before proposing any version change. Do not modify manifests, build or publish images, or merge changes merely because a newer release exists.

The scheduled `.github/workflows/check-upstream-versions.yml` currently opens manifest-only bump PRs for Bifrost, Headroom, LiteLLM, SQZ, and `atlassian-mcp`. It skips Gnosis and AgentMemory because their lockfiles/compatibility require coordinated work; it does not cover every directory above. Its PRs are candidates for review, not evidence that the images build or that a full repository-wide review is complete. Keep this table and the workflow's coverage aligned when images are added or removed.
