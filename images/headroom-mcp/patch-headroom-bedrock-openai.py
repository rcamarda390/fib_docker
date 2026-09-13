#!/usr/bin/env python3
"""Apply non-caching Bedrock/OpenAI compatibility fixes for PR 3565 testing."""
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
new = '''            extra_body = _build_openai_extra_body(body)\n            if self.provider == "bedrock":\n                # Cline sends parallel_tool_calls, but Headroom 0.37.0 treats it\n                # as extra_body. Do not forward that raw OpenAI field to Bedrock.\n                extra_body.pop("parallel_tool_calls", None)\n            if extra_body:\n                kwargs["extra_body"] = extra_body\n'''
count = text.count(old)
if count != 2:
    raise SystemExit(
        f"expected exactly 2 OpenAI extra_body call sites in {path}, found {count}; "
        "review patch against the pinned Headroom source"
    )
text = text.replace(old, new)

path.write_text(text)
print(f"Patched {path}: OpenAI max_completion_tokens + Bedrock compatibility; no custom prompt-cache injection")
