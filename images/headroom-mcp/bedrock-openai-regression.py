#!/usr/bin/env python3
"""Build-time regression tests for fib_docker's Headroom Bedrock patch."""
import asyncio

import headroom.backends.litellm as module
import litellm.utils


class StopCall(RuntimeError):
    pass


def backend(provider: str):
    b = module.LiteLLMBackend.__new__(module.LiteLLMBackend)
    b.provider = provider
    b.region = "us-gov-west-1" if provider == "bedrock" else None
    b.profile_name = None
    # PR 3565 owns prompt-cache rollout behavior; this build test exercises
    # only the unrelated downstream compatibility carry.
    b._openai_prompt_caching = False
    b.map_model_id = lambda model: f"{provider}/{model}"
    return b


async def capture_nonstream(provider: str, body: dict, *, cache_supported: bool = True):
    captured = {}

    async def fake(**kwargs):
        captured.update(kwargs)
        raise StopCall("captured")

    original_completion = module.acompletion
    original_supported = litellm.utils.supports_prompt_caching
    module.acompletion = fake
    litellm.utils.supports_prompt_caching = lambda **_: cache_supported
    try:
        await backend(provider).send_openai_message(body, {})
    finally:
        module.acompletion = original_completion
        litellm.utils.supports_prompt_caching = original_supported
    return captured


async def capture_stream(provider: str, body: dict, *, cache_supported: bool = True):
    captured = {}

    async def fake(**kwargs):
        captured.update(kwargs)
        raise StopCall("captured")

    original_completion = module.acompletion
    original_supported = litellm.utils.supports_prompt_caching
    module.acompletion = fake
    litellm.utils.supports_prompt_caching = lambda **_: cache_supported
    try:
        async for _ in backend(provider).stream_openai_message(body, {}):
            pass
    finally:
        module.acompletion = original_completion
        litellm.utils.supports_prompt_caching = original_supported
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
        "max_completion_tokens": 20,
    }

    # Both OpenAI paths retain only the unrelated compatibility carry here.
    for capture in (capture_nonstream, capture_stream):
        got = await capture("bedrock", body, cache_supported=True)
        assert "parallel_tool_calls" not in got.get("extra_body", {})
        assert got["max_completion_tokens"] == 20
        assert "max_completion_tokens" not in got.get("extra_body", {})
        assert "cache_control_injection_points" not in got
        assert not any("cache_control" in m for m in got["messages"])

    # No custom cache marker is added by this downstream patch.
    got = await capture_nonstream("bedrock", body, cache_supported=False)
    assert "cache_control_injection_points" not in got
    assert not any("cache_control" in m for m in got["messages"])

    # Non-Bedrock providers retain the original OpenAI passthrough behavior and
    # never receive our Bedrock-specific cache markers.
    got = await capture_nonstream("openrouter", body, cache_supported=True)
    assert got["extra_body"]["parallel_tool_calls"] is True
    assert "cache_control_injection_points" not in got
    assert not any("cache_control" in m for m in got["messages"])

    # No system prompt remains unchanged.
    dynamic_only = dict(body)
    dynamic_only["messages"] = [{"role": "user", "content": "changes"}]
    got = await capture_nonstream("bedrock", dynamic_only, cache_supported=True)
    assert not any("cache_control" in m for m in got["messages"])

    # List-form system content remains unchanged by this downstream patch.
    block_system = dict(body)
    block_system["messages"] = [
        {
            "role": "system",
            "content": [
                {"type": "text", "text": "prefix"},
                {"type": "text", "text": "stable suffix"},
            ],
        },
        {"role": "user", "content": "dynamic"},
    ]
    got = await capture_nonstream("bedrock", block_system, cache_supported=True)
    system = got["messages"][0]
    assert all("cache_control" not in block for block in system["content"])

    print("Bedrock OpenAI regression tests: PASS")


asyncio.run(main())
