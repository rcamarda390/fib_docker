#!/bin/sh
set -eu

DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
SECRET_FILE="${AGENTMEMORY_SECRET_FILE:-${DATA_DIR}/.agentmemory-secret}"
RUN_AS="node:node"

mkdir -p "$DATA_DIR"
chown -R "$RUN_AS" "$DATA_DIR"

if [ ! -s "$SECRET_FILE" ]; then
  umask 077
  openssl rand -hex 32 > "$SECRET_FILE"
  chown "$RUN_AS" "$SECRET_FILE"
  echo "agentmemory: generated persistent HMAC secret at $SECRET_FILE"
fi

export AGENTMEMORY_SECRET="$(cat "$SECRET_FILE")"

exec gosu "$RUN_AS" "$@"
