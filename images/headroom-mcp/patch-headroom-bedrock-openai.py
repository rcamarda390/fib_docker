#!/usr/bin/env python3
"""Apply fib_docker's Headroom 0.35.0 Bedrock/OpenAI compatibility patch.

This is intentionally a build-time source patch. It fails closed if the pinned
upstream source no longer matches the expected 0.35.0 call sites, forcing the
patch to be reviewed when Headroom is upgraded.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("headroom/backends/litellm.py")
text = path.read_text()

old = '''            extra_body = _build_openai_extra_body(body)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n'''
new = '''            extra_body = _build_openai_extra_body(body)\n            if self.provider == "bedrock":\n                # OpenAI clients such as Cline send parallel_tool_calls, but\n                # Bedrock rejects it as an unknown Converse input. Keep the\n                # passthrough behavior unchanged for providers that support it.\n                extra_body.pop("parallel_tool_calls", None)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n\n            if self.provider == "bedrock":\n                # Cline's OpenAI-compatible transport does not emit Anthropic\n                # cache_control markers. Ask LiteLLM to place Bedrock cache\n                # points only at stable boundaries: the system prompt and,\n                # when present, the tool configuration. Do not mark user or\n                # assistant conversation turns, which change on every request.\n                cache_points = []\n                if any(message.get("role") == "system" for message in kwargs["messages"]):\n                    cache_points.append({"location": "message", "role": "system"})\n                if body.get("tools"):\n                    cache_points.append({"location": "tool_config"})\n                if cache_points:\n                    kwargs["cache_control_injection_points"] = cache_points\n'''

count = text.count(old)
if count != 2:
    raise SystemExit(
        f"expected exactly 2 OpenAI extra_body call sites in {path}, found {count}; "
        "review patch against the pinned Headroom source"
    )

text = text.replace(old, new)
path.write_text(text)
print(f"Patched {path}: Bedrock parallel_tool_calls filter + stable prompt-cache injection")
