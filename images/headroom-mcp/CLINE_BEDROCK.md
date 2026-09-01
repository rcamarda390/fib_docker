# Cline 4.0.12 → Headroom 0.37.0 → AWS Bedrock

This image carries a downstream Headroom 0.37.0 compatibility patch for Cline's
OpenAI-compatible transport to AWS Bedrock.

## Request shaping

Cline 4.0.12 sends `parallel_tool_calls=true`. Headroom 0.37.0 treats unknown
OpenAI request keys as `extra_body`, and LiteLLM consequently forwards this key
toward Bedrock, which rejects it. The downstream patch removes only
`parallel_tool_calls` from `extra_body` when the configured Headroom provider is
`bedrock`. Other providers retain the existing passthrough behavior.

Both `send_openai_message()` and `stream_openai_message()` are patched.

## Bedrock prompt caching

Cline's OpenAI-compatible path does not emit Bedrock cache markers. The v41
hotfix enables prompt caching only when LiteLLM reports that the exact Bedrock
model supports the OpenAI `cache_control` parameter.

For supported models, the patch adds:

```json
{"cache_control":{"type":"ephemeral"}}
```

to the stable system message (or the last block of list-form system content).
LiteLLM 1.88.1 natively converts that message-level marker into a Bedrock
Converse `cachePoint`.

For models that do not report `cache_control` support, no marker is added and
the request proceeds normally with prompt caching effectively off.

The previous `cache_control_injection_points` approach was removed. In the
Headroom/LiteLLM 1.88.1 path it could reach Bedrock as a raw Converse request
field, producing:

```text
cache_control_injection_points: Extra inputs are not permitted
```

Dynamic user and assistant turns are not automatically marked. The system
prefix is the highest-value stable region for Cline and avoids moving cache
breakpoints as the conversation grows.

Tool-config caching is intentionally not injected by this patch because the
installed LiteLLM 1.88.1 path has a verified native system-message conversion,
but no equally reliable tool-config marker path was found. This avoids trading
cache savings for request failures.

## Output-token shaping

The image enables Headroom's output shaper with:

```text
HEADROOM_OUTPUT_SHAPER=1
```

Headroom 0.37.0 reads this setting live on each proxy request. No fixed
`HEADROOM_VERBOSITY_LEVEL` is set.

`headroom learn --verbosity --apply` remains a deployment-time operation because
it depends on agent session history.

## Health check in the air-gapped deployment

The image sets `HEADROOM_SKIP_UPSTREAM_CHECK=1` to suppress Headroom 0.37.0's
external upstream readiness probe in the air-gapped Bedrock deployment. This
does not weaken TLS verification for Bedrock traffic.

## Build strategy

The patch is applied inside the main `Dockerfile` builder stage, directly to the
venv produced from the pinned upstream source. One action now produces the
finished image; there is no intermediate base image or second carry build.

The patch script expects exactly two Headroom 0.37.0 OpenAI call sites and fails
the build if the upstream source shape changes. Both are present and
byte-identical at `v0.37.0`. The build compiles the patched module and runs the
regression suite before copying the venv into the runtime image.

The patch and regression scripts remain in the builder stage. Only the patched
`/opt/venv` and the pre-cached compression assets cross into the runtime image.

## Upgrading Headroom while this carry exists

A version bump is one build. `images/headroom-mcp/image.yaml` carries the
upstream version, revision floor, and exact upstream commit.

1. Bump `upstream_version` and `build_args.HEADROOM_COMMIT` to the new tag and
   its commit (`git ls-remote --tags https://github.com/headroomlabs-ai/headroom.git`),
   reset `revision` to `1`, and update `ARG HEADROOM_VERSION` /
   `ARG HEADROOM_COMMIT` in `Dockerfile` to match. The build asserts the installed
   `headroom-ai` version equals `HEADROOM_VERSION`, and the source stage
   asserts the cloned tag equals `HEADROOM_COMMIT`, so a mismatch fails the
   build rather than shipping.
2. Re-verify the patch against the new release with the command below.
3. Merge the version PR. The push to `main` starts **Build and publish Headroom
   MCP image**, and the shared workflow forces a changed upstream version to
   revision `v1`.

Re-verify the patch before merging rather than discovering an anchor change in
CI. From `images/headroom-mcp/`, against the real package:

```bash
uv venv --python 3.13 /tmp/hr && \
uv pip install --python /tmp/hr/bin/python "headroom-ai==<new-version>" && \
target=$(/tmp/hr/bin/python -c 'import headroom.backends.litellm as m; print(m.__file__)') && \
/tmp/hr/bin/python patch-headroom-bedrock-openai.py "$target" && \
/tmp/hr/bin/python -m py_compile "$target" && \
/tmp/hr/bin/python bedrock-openai-regression.py
```

This is the same patch, compile, and regression sequence the Dockerfile runs.
The patch fails closed when the two call sites it anchors on no longer match.

## Verification

`bedrock-openai-regression.py` runs during the image build and verifies:

1. non-streaming Bedrock drops the unsafe `parallel_tool_calls` passthrough;
2. streaming Bedrock receives the same protection;
3. supported Bedrock models get native system `cache_control` markers;
4. unsupported Bedrock models receive no cache marker;
5. `cache_control_injection_points` is never sent;
6. non-Bedrock providers remain unchanged;
7. dynamic user/assistant turns are not marked;
8. list-form system content receives the marker on its last block.

After deployment, verify a sufficiently large stable Cline request reports
cache creation tokens on the first call and cache read tokens on a repeated
request, while normal Cline tool calls continue to succeed.

## Dashboard

Headroom serves per-request data (`recent_requests`, `/transformations/feed`)
only to loopback callers, which a bridge-network container is not. See
`DASHBOARD_TELEMETRY.md` for why the dashboard's Recent Requests table stays
empty while aggregate telemetry populates, and how to configure around it.
