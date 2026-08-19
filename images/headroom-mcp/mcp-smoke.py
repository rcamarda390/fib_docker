import json
import subprocess
import time
import urllib.request
import urllib.error

# Start proxy server
process = subprocess.Popen(
    ["headroom", "proxy", "--host", "0.0.0.0", "--port", "8787"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
)

# Wait for server to be ready
max_retries = 30
retry_count = 0
while retry_count < max_retries:
    try:
        response = urllib.request.urlopen("http://localhost:8787/health", timeout=2)
        if response.status == 200:
            break
    except (urllib.error.URLError, OSError):
        pass
    retry_count += 1
    time.sleep(0.5)

if retry_count >= max_retries:
    process.terminate()
    process.wait(timeout=5)
    raise SystemExit("Proxy server failed to start within 15 seconds")

try:
    # Verify health endpoint
    response = urllib.request.urlopen("http://localhost:8787/health", timeout=2)
    if response.status != 200:
        raise SystemExit(f"Health check failed with status {response.status}")
    print("Proxy health check OK")

    # Verify dashboard is available
    response = urllib.request.urlopen("http://localhost:8787/dashboard", timeout=2)
    if response.status != 200:
        raise SystemExit(f"Dashboard check failed with status {response.status}")
    print("Proxy dashboard OK")

finally:
    process.terminate()
    process.wait(timeout=5)
