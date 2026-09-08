#!/bin/bash
# Verifies the tools this image is supposed to ship.
#
# Default (no args): print a report, warn on anything missing, but always
# exit 0 -- safe for a `test` build where some public-source research item
# may still be unresolved.
#
# --prod: same report, but exit 1 if any REQUIRED item is missing. Used by
# the Dockerfile's final verification step when BUILD_MODE=production.
set -u

PROD=0
[ "${1:-}" = "--prod" ] && PROD=1

REPORT=/tmp/installation-verification-report.txt
: > "$REPORT"

failures=0

log() {
    printf '%s\n' "$1" | tee -a "$REPORT"
}

# check NAME REQUIRED(0|1) COMMAND...
check() {
    name=$1
    required=$2
    shift 2
    if "$@" >/dev/null 2>&1; then
        log "OK   $name"
        return 0
    fi
    if [ "$required" = "1" ]; then
        log "FAIL $name (required)"
        failures=$((failures + 1))
    else
        log "WARN $name (optional, not installed)"
    fi
    return 1
}

log "=== zeus-dev-image installation verification ==="

check "python3" 1 command -v python3
check "pip3" 1 command -v pip3
check "node" 1 command -v node
check "npm" 1 command -v npm
check "git" 1 command -v git
check "docker CLI" 0 command -v docker
check "aws CLI" 1 command -v aws
check "jira python package" 1 python3 -c "import jira"
check "jirashell" 1 command -v jirashell
check "apache-airflow" 1 python3 -c "import airflow"
check "sqlfluff" 0 command -v sqlfluff
check "ruff" 0 command -v ruff
check "pyright" 0 command -v pyright
check "cline CLI" 1 command -v cline
check "claude CLI" 1 command -v claude
check "sqz CLI" 1 command -v sqz
check "AgentMemory MCP entry point" 1 test -f /opt/agentmemory/node_modules/@agentmemory/agentmemory/dist/index.mjs
check "agentmemory-mcp.sh wrapper" 1 test -x /usr/local/bin/agentmemory-mcp.sh

log ""
log "=== opaque binaries intentionally omitted (see BUILD-MANIFEST.md) ==="
log "SKIP archify (no confirmed public equivalent for the pinned internal version)"
log "SKIP gitlab-server-node-modules (internal-only tooling)"

log ""
if [ "$failures" -gt 0 ]; then
    log "$failures required item(s) missing."
    if [ "$PROD" = "1" ]; then
        exit 1
    fi
    log "BUILD_MODE=test: not failing the build."
else
    log "All required items present."
fi

exit 0
