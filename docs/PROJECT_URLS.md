# Project URLs

Use these links to identify projects. Check an image's `image.yaml`, Dockerfile, and build workflow for the actual source and version before recommending an update. This list also includes related projects that are not built by this repository.

| Project | GitHub source | Documentation or releases | Repository use |
| --- | --- | --- | --- |
| Headroom | https://github.com/headroomlabs-ai/headroom | https://docs.headroomlabs.ai/docs | `images/headroom-mcp` |
| AgentMemory | https://github.com/rohitg00/agentmemory | https://github.com/rohitg00/agentmemory/blob/main/CHANGELOG.md | `images/agentmemory-server` |
| OmniRoute | https://github.com/diegosouzapw/OmniRoute | https://github.com/diegosouzapw/OmniRoute/wiki/User-Guide ; https://github.com/diegosouzapw/OmniRoute/blob/release/v3.8.51/docs/guides/DOCKER_GUIDE.md | Related project; no image listed here |
| Bifrost | https://github.com/maximhq/bifrost | https://docs.getbifrost.ai/overview | `images/bifrost-mcp` |
| Gnosis MCP | https://github.com/nicholasglazer/gnosis-mcp | https://pypi.org/project/gnosis-mcp/ | `images/gnosis-mcp` |
| Gnosis (different project) | https://github.com/skorokithakis/gnosis | — | Related project; not the source of `images/gnosis-mcp` |
| Atlassian Rovo MCP (official) | https://github.com/atlassian/atlassian-mcp-server | https://support.atlassian.com/atlassian-rovo-mcp-server/docs/getting-started-with-the-atlassian-remote-mcp-server/ | Related cloud service; not the source of either Atlassian image |
| Sooperset MCP Atlassian (used here) | https://github.com/sooperset/mcp-atlassian | https://pypi.org/project/mcp-atlassian/ | Source for both `images/atlassian-mcp` and `images/sooperset-mcp-atlassian` |

The two Atlassian image directories have separate build inputs and version revisions. Check each independently. Their directory names do not imply that either image contains Atlassian's official MCP server.
