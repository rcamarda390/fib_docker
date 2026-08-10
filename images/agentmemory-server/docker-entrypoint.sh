#!/bin/sh
set -eu

DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
SECRET_FILE="${AGENTMEMORY_SECRET_FILE:-${DATA_DIR}/.agentmemory-secret}"
RUN_AS="node:node"

mkdir -p "$DATA_DIR"
chown -R "$RUN_AS" "$DATA_DIR"

if [ ! -s "$SECRET_FILE" ]; then
  umask 077
  SECRET="$(openssl rand -hex 32)"
  printf '%s\n' "$SECRET" > "$SECRET_FILE"
  chown "$RUN_AS" "$SECRET_FILE"
  echo "================================================================"
  echo "agentmemory: generated HMAC secret on first boot"
  echo "AGENTMEMORY_SECRET=$SECRET"
  echo "Copy this value now for devcontainer MCP client configs."
  echo "Stored at: $SECRET_FILE (chmod 600). It will not be printed again."
  echo "To rotate: delete $SECRET_FILE and restart this container."
  echo "================================================================"
fi

export AGENTMEMORY_SECRET="$(cat "$SECRET_FILE")"

# CMD supplies trailing args to the agentmemory CLI (e.g. `doctor --all` for
# `docker run --rm <image> doctor --all`), not a full command line -- there
# is nothing else on PATH worth exec'ing directly in this image.
exec gosu "$RUN_AS" agentmemory "$@"
