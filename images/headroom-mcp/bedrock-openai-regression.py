#!/usr/bin/env python3
"""Build-time regression tests for fib_docker's Headroom Bedrock patch."""
import asyncio
from types import SimpleNamespace

import headroom.backends.litellm as module


class StopCall(RuntimeError):
    pass


def backend(provider: str):
    b = module.LiteLLMBackend.__new__(module.LiteLLMBackend)
    b.provider = provider
    b.region = "us-gov-west-1" if provider == "bedrock" else None
    b.profile_name = None
    b.map_model_id = lambda model: f"{provider}/{model}"
    return b


async def capture_nonstream(provider: str, body: dict):
    captured = {}

    async def fake(**kwargs):
        captured.update(kwargs)
        raise StopCall("captured")

    original = module.acompletion
    module.acompletion = fake
    try:
        await backend(provider).send_openai_message(body, {})
    finally:
        module.acompletion = original
    return captured


async def capture_stream(provider: str, body: dict):
    captured = {}

    async def fake(**kwargs):
        captured.update(kwargs)
        raise StopCall("captured")

    original = module.acompletion
    module.acompletion = fake
    try:
        async for _ in backend(provider).stream_openai_message(body, {}):
            pass
    finally:
        module.acompletion = original
    return captured


async def main():
    body = {
        "model": "us-gov.anthropic.claude-sonnet-5",
        "messages": [
            {"role": "system", "content": "stable system prompt"},
            {"role": "user", "content": "dynamic request"},
        ],
        "tools": [
            {
                "type": "function",
                "function": {
                    "name": "read_file",
                    "description": "read a file",
                    "parameters": {"type": "object", "properties": {}},
                },
            }
        ],
        "parallel_tool_calls": True,
    }

    expected_points = [
        {"location": "message", "role": "system"},
        {"location": "tool_config"},
    ]

    for capture in (capture_nonstream, capture_stream):
        got = await capture("bedrock", body)
        assert "parallel_tool_calls" not in got.get("extra_body", {})
        assert got["cache_control_injection_points"] == expected_points
        assert not any(p.get("role") in {"user", "assistant"} for p in expected_points)

    # Provider-specific behavior: non-Bedrock providers retain the OpenAI field
    # and do not receive Bedrock cache-control injection points.
    got = await capture_nonstream("openrouter", body)
    assert got["extra_body"]["parallel_tool_calls"] is True
    assert "cache_control_injection_points" not in got

    # No tools means no tool_config cache point; no system means no automatic
    # cache point at all. This protects dynamic conversation content.
    no_tools = dict(body)
    no_tools.pop("tools")
    got = await capture_nonstream("bedrock", no_tools)
    assert got["cache_control_injection_points"] == [
        {"location": "message", "role": "system"}
    ]

    dynamic_only = dict(body)
    dynamic_only["messages"] = [{"role": "user", "content": "changes"}]
    dynamic_only.pop("tools")
    got = await capture_nonstream("bedrock", dynamic_only)
    assert "cache_control_injection_points" not in got

    print("Bedrock OpenAI regression tests: PASS")


asyncio.run(main())
