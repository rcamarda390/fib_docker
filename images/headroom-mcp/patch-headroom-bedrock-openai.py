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
new = '''            extra_body = _build_openai_extra_body(body)\n            if self.provider == "bedrock":\n                # Cline sends parallel_tool_calls, but Headroom 0.35.0 treats it\n                # as extra_body. Do not forward that raw OpenAI field to Bedrock.\n                extra_body.pop("parallel_tool_calls", None)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n\n            if self.provider == "bedrock":\n                # Enable prompt caching only when LiteLLM says this exact Bedrock\n                # model supports OpenAI-style cache_control. Do not use the\n                # top-level cache_control_injection_points parameter here: in\n                # LiteLLM 1.88.1 it can bypass the cache-control hook and leak\n                # into Bedrock Converse as an unsupported request field.\n                try:\n                    supported_params = litellm.get_supported_openai_params(\n                        model=original_model, custom_llm_provider="bedrock"\n                    ) or []\n                except Exception:\n                    supported_params = []\n\n                if "cache_control" in supported_params:\n                    # Copy before marking so the incoming request body remains\n                    # unchanged. LiteLLM 1.88.1 natively converts a system\n                    # message/content-block cache_control marker into a Bedrock\n                    # Converse cachePoint. The stable Cline system prefix is the\n                    # highest-value cache target; dynamic user/assistant turns\n                    # are deliberately left unmarked.\n                    marked_messages = []\n                    system_marked = False\n                    for message in kwargs["messages"]:\n                        marked = dict(message)\n                        if not system_marked and marked.get("role") == "system":\n                            content = marked.get("content")\n                            if isinstance(content, str) and content:\n                                marked["cache_control"] = {"type": "ephemeral"}\n                                system_marked = True\n                            elif isinstance(content, list) and content:\n                                blocks = [dict(b) if isinstance(b, dict) else b for b in content]\n                                for idx in range(len(blocks) - 1, -1, -1):\n                                    if isinstance(blocks[idx], dict):\n                                        blocks[idx]["cache_control"] = {"type": "ephemeral"}\n                                        marked["content"] = blocks\n                                        system_marked = True\n                                        break\n                        marked_messages.append(marked)\n                    kwargs["messages"] = marked_messages\n'''

count = text.count(old)
if count != 2:
    raise SystemExit(
        f"expected exactly 2 OpenAI extra_body call sites in {path}, found {count}; "
        "review patch against the pinned Headroom source"
    )

text = text.replace(old, new)
path.write_text(text)
print(f"Patched {path}: Bedrock OpenAI compatibility + capability-gated native cache_control")
