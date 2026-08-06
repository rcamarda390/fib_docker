import json
import subprocess

request = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
        "protocolVersion": "2024-11-05",
        "capabilities": {},
        "clientInfo": {"name": "headroom-smoke", "version": "1"},
    },
}

process = subprocess.Popen(
    ["headroom", "mcp", "serve"],
    stdin=subprocess.PIPE,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)
try:
    stdout, stderr = process.communicate(json.dumps(request) + "\n", timeout=10)
except subprocess.TimeoutExpired:
    process.kill()
    raise SystemExit("MCP initialize timed out")

if process.returncode != 0:
    raise SystemExit(f"MCP server exited with {process.returncode}: {stderr}")

responses = [json.loads(line) for line in stdout.splitlines() if line.strip()]
if not any(response.get("id") == 1 and "result" in response for response in responses):
    raise SystemExit(f"Missing MCP initialize response: {stdout}")

print("MCP initialize OK")
