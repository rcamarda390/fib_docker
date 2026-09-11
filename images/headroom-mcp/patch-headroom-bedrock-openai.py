#!/usr/bin/env python3
"""Apply fib_docker's Headroom 0.37.0 Bedrock/OpenAI compatibility patch."""
from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("headroom/backends/litellm.py")
text = path.read_text()

allowed_params_old = '''_OPENAI_STANDARD_PARAMS = (\n    "max_tokens",\n    "temperature",\n'''
allowed_params_new = '''_OPENAI_STANDARD_PARAMS = (\n    "max_tokens",\n    "max_completion_tokens",\n    "temperature",\n'''
allowed_params_count = text.count(allowed_params_old)
if allowed_params_count != 1:
    raise SystemExit(
        f"expected exactly 1 OpenAI standard-parameter tuple in {path}, "
        f"found {allowed_params_count}; review patch against the pinned Headroom source"
    )
text = text.replace(allowed_params_old, allowed_params_new)

old = '''            extra_body = _build_openai_extra_body(body)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n'''
new = '''            extra_body = _build_openai_extra_body(body)\n            if self.provider == "bedrock":\n                # Cline sends parallel_tool_calls, but Headroom 0.37.0 treats it\n                # as extra_body. Do not forward that raw OpenAI field to Bedrock.\n                extra_body.pop("parallel_tool_calls", None)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n\n            if self.provider == "bedrock":\n                # LiteLLM's OpenAI-parameter list omits cache_control for Bedrock,\n                # so use its dedicated prompt-caching capability API.\n                try:\n                    from litellm.utils import supports_prompt_caching\n                    cache_control_supported = supports_prompt_caching(\n                        model=original_model, custom_llm_provider="bedrock"\n                    )\n                except Exception:\n                    cache_control_supported = False\n\n                if cache_control_supported:\n                    # Copy before marking so the incoming request body remains\n                    # unchanged. LiteLLM converts this native marker to a Bedrock\n                    # Converse cachePoint on the stable system prefix.\n                    marked_messages = []\n                    system_marked = False\n                    for message in kwargs["messages"]:\n                        marked = dict(message)\n                        if not system_marked and marked.get("role") == "system":\n                            content = marked.get("content")\n                            if isinstance(content, str) and content:\n                                marked["cache_control"] = {"type": "ephemeral"}\n                                system_marked = True\n                            elif isinstance(content, list) and content:\n                                blocks = [dict(b) if isinstance(b, dict) else b for b in content]\n                                for idx in range(len(blocks) - 1, -1, -1):\n                                    if isinstance(blocks[idx], dict):\n                                        blocks[idx]["cache_control"] = {"type": "ephemeral"}\n                                        marked["content"] = blocks\n                                        system_marked = True\n                                        break\n                        marked_messages.append(marked)\n                    kwargs["messages"] = marked_messages\n'''
count = text.count(old)
if count != 2:
    raise SystemExit(
        f"expected exactly 2 OpenAI extra_body call sites in {path}, found {count}; "
        "review patch against the pinned Headroom source"
    )
text = text.replace(old, new)

cache_gate = '''                try:\n                    from litellm.utils import supports_prompt_caching\n                    cache_control_supported = supports_prompt_caching(\n                        model=original_model, custom_llm_provider="bedrock"\n                    )\n                except Exception:\n                    cache_control_supported = False\n\n                if cache_control_supported:\n'''
cache_gate_count = text.count(cache_gate)
if cache_gate_count != 2:
    raise SystemExit(
        f"expected exactly 2 prompt-caching gates in {path}, found {cache_gate_count}; "
        "review patch against the pinned Headroom source"
    )

path.write_text(text)
print(
    f"Patched {path}: OpenAI max_completion_tokens + Bedrock compatibility + "
    "capability-gated native cache_control"
)
