# Cline 4.0.12 → Headroom 0.35.0 → AWS Bedrock

This image carries a downstream Headroom 0.35.0 compatibility patch for Cline's
OpenAI-compatible transport to AWS Bedrock.

## Request shaping

Cline 4.0.12 sends `parallel_tool_calls=true`. Headroom 0.35.0 treats unknown
OpenAI request keys as `extra_body`, and LiteLLM consequently forwards this key
toward Bedrock, which rejects it. The downstream patch removes only
`parallel_tool_calls` from `extra_body` when the configured Headroom provider is
`bedrock`. Other providers retain the existing passthrough behavior.

Both `send_openai_message()` and `stream_openai_message()` are patched.

## Bedrock prompt caching

Cline's OpenAI-compatible path does not send Anthropic/Bedrock cache-control
markers. For Bedrock only, the image supplies LiteLLM
`cache_control_injection_points` at stable boundaries:

- the system message, when present;
- `tool_config`, when tools are present.

No user or assistant conversation message is automatically marked. This avoids
placing cache points on the dynamic tail of an agent conversation while still
covering Cline's large, relatively stable system prompt and tool schema.

Headroom 0.35.0 requires LiteLLM `>=1.86.2,<2.0`; this generation supports both
message and `tool_config` cache-control injection points for Bedrock Converse.
Bedrock still applies its model-specific minimum cacheable-token requirements.

## Output-token shaping

The image enables Headroom's output shaper with:

```text
HEADROOM_OUTPUT_SHAPER=1
```

Headroom 0.35.0 reads this setting live on each proxy request. This enables
output-token shaping and allows the dashboard to begin measuring output-token
savings. No fixed `HEADROOM_VERBOSITY_LEVEL` is set, so Headroom can use its
learned/default behavior rather than forcing one global verbosity level.

`headroom learn --verbosity --apply` is intentionally not run during the image
build. Verbosity learning depends on agent session history and should be run in
the deployed environment when a supported history source is available. Headroom
0.35.0 documents built-in session scanners for Claude Code, Codex, and Gemini
CLI; Cline history is not listed as a built-in scanner in that release.

## Health check in the air-gapped deployment

Headroom 0.35.0's readiness connectivity probe can target the Anthropic HTTP
upstream even when the active backend is Bedrock. The image sets the upstream-
supported `HEADROOM_SKIP_UPSTREAM_CHECK=1` switch. This skips only that probe;
it does not disable TLS certificate verification for Bedrock or other traffic.

## Build strategy

`Dockerfile.cline-bedrock` derives from the last verified `0.35.0-v36` custom
image and applies the source patch during the image build. This preserves the
existing boto3/botocore installation, hardening, and pre-cached compression
assets without mutating source at container startup or downloading anything at
runtime.

The patch script deliberately expects exactly two matching Headroom 0.35.0
OpenAI call sites and fails the build if upstream source shape changes. Remove
the downstream carry and return the workflow to the normal Dockerfile when an
upstream Headroom release contains equivalent fixes.

## Verification

`bedrock-openai-regression.py` runs during the image build and verifies:

1. non-streaming Bedrock requests drop `parallel_tool_calls`;
2. streaming Bedrock requests receive the same protection;
3. non-Bedrock providers retain `parallel_tool_calls` passthrough;
4. Bedrock OpenAI requests with system + tools receive system and `tool_config`
   cache injection points;
5. requests without stable system/tool boundaries do not cache dynamic turns.

For output shaping, verify after deployment that `/health` reports
`HEADROOM_OUTPUT_SHAPER=1` in the effective runtime environment and that normal
Cline agent/tool requests remain successful. The dashboard can then accumulate
output-token savings measurements.

Live GovCloud acceptance should also verify cache creation on the first
sufficiently large request, cache reads on an identical second request, and a
real Cline tool-call round trip.
