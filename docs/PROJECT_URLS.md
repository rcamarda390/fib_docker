# Project URLs and upstream checks

This repository: https://github.com/rcamarda390/fib_docker

Use this index to find upstream projects. Read each image's `image.yaml`, Dockerfile, workflow, and image-specific documentation before deciding whether an update applies. `image.yaml` records the currently configured image version; this index does not replace it.

| Image directory | Upstream project | Release or package source |
| --- | --- | --- |
| `agentmemory-server` | https://github.com/rohitg00/agentmemory | https://www.npmjs.com/package/@agentmemory/agentmemory (also depends on https://github.com/iii-hq/iii) |
| `atlassian-mcp` | https://github.com/sooperset/mcp-atlassian | https://pypi.org/project/mcp-atlassian/ |
| `bifrost-mcp` | https://github.com/maximhq/bifrost | https://github.com/maximhq/bifrost/releases |
| `docker-socket-proxy` | https://github.com/Tecnativa/docker-socket-proxy | https://github.com/Tecnativa/docker-socket-proxy/releases (check the HAProxy base image separately) |
| `ebay-mcp` | https://github.com/YosefHayim/ebay-mcp | https://github.com/YosefHayim/ebay-mcp/releases |
| `gnosis-mcp` | https://github.com/nicholasglazer/gnosis-mcp | https://pypi.org/project/gnosis-mcp/ |
| `headroom-mcp` | https://github.com/headroomlabs-ai/headroom | https://github.com/headroomlabs-ai/headroom/releases |
| `litellm` | https://github.com/BerriAI/litellm | https://github.com/BerriAI/litellm/releases |
| `nginx` | https://github.com/nginx/nginx | https://nginx.org/en/download.html |
| `sooperset-mcp-atlassian` | https://github.com/sooperset/mcp-atlassian | https://pypi.org/project/mcp-atlassian/ |
| `sqz-mcp` | https://github.com/ojuschugh1/sqz | https://github.com/ojuschugh1/sqz/releases |
| `zeus-dev-image` | Composite local image; see `images/zeus-dev-image/Dockerfile` | Check each installed tool and pinned source individually, including https://github.com/tt-a1i/archify and https://gitlab.freedesktop.org/xdg/xdg-user-dirs |

## Checking every image

When asked to check for updates, inventory **all** `images/*/image.yaml` files and compare every image with its authoritative release source. Report the configured version, newest applicable stable upstream version, source URL, release date, and whether a change is available. Mark inaccessible or incomparable sources as **unverified**, not current. For composite images, report the relevant components separately. Check the image-specific build inputs and compatibility before recommending an upgrade; a newer upstream release alone does not establish build or runtime safety.

The scheduled `.github/workflows/check-upstream-versions.yml` currently covers only a subset of the images. Its proposed version-bump PRs require review and do not replace the full inventory above. Do not edit or publish images merely to perform an update check.
