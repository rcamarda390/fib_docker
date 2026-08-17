#!/bin/sh
set -eu

# Ensure venv is in PATH for all operations
export PATH="/opt/venv/bin:${PATH}"

if [ "${1:-}" = "__smoke" ]; then
    exec /opt/venv/bin/python /usr/local/bin/mcp-smoke.py
fi

exec /opt/venv/bin/headroom mcp serve "$@"
