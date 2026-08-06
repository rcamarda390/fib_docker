#!/bin/sh
set -eu

if [ "${1:-}" = "__smoke" ]; then
    exec python /usr/local/bin/mcp-smoke.py
fi

exec headroom mcp serve "$@"
