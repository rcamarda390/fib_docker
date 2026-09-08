#!/bin/bash
# zeus-dev-image entrypoint.
#
# Wires the custom prompt into interactive bash sessions, makes sure the
# host-tmp share is usable, and then execs the container CMD (normally
# `tail -f /dev/null`, so the container just stays up for `docker exec`).
set -eu

if ! grep -q new_prompt.sh /etc/bash.bashrc 2>/dev/null; then
    echo '. /usr/local/share/new_prompt.sh' >> /etc/bash.bashrc
fi

mkdir -p /host-tmp
chmod 1777 /host-tmp

exec "$@"
