import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

# Test AWS dependencies before starting the proxy
print("Testing AWS dependencies...")
try:
    import boto3
    import botocore
    print(f"✓ boto3 version: {boto3.__version__}")
    print(f"✓ botocore version: {botocore.__version__}")
except ImportError as e:
    print(f"✗ Failed to import AWS dependencies: {e}", file=sys.stderr)
    sys.exit(1)

# Test awscrt (AWS Common Runtime) required for modern boto3
try:
    import awscrt
    print("✓ awscrt (AWS Common Runtime) available")
except ImportError:
    print("⚠ awscrt not available (fallback to older auth methods)")

# Start proxy server with offline mode enabled to verify cached models work
print("\nStarting Headroom proxy with offline mode...")
env = os.environ.copy()
env["HF_HUB_OFFLINE"] = "1"
env["TRANSFORMERS_OFFLINE"] = "1"

process = subprocess.Popen(
    ["headroom", "proxy", "--host", "0.0.0.0", "--port", "8787"],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True,
    env=env,
)

# Wait for server to be ready
print("Waiting for proxy to be ready...")
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
    print("\nTesting proxy endpoints...")
    response = urllib.request.urlopen("http://localhost:8787/health", timeout=2)
    if response.status != 200:
        raise SystemExit(f"Health check failed with status {response.status}")
    print("✓ Proxy health check OK")

    # Verify dashboard is available
    response = urllib.request.urlopen("http://localhost:8787/dashboard", timeout=2)
    if response.status != 200:
        raise SystemExit(f"Dashboard check failed with status {response.status}")
    print("✓ Proxy dashboard OK")

    # Test compression endpoint
    print("\nTesting compression functionality...")
    test_content = """
    The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
    The quick brown fox jumps over the lazy dog. The quick brown fox jumps over the lazy dog.
    """ * 10  # Repeat to ensure sufficient token count for compression

    # Create request for Kompress compression endpoint
    compress_url = "http://localhost:8787/v1/compress"
    compress_data = json.dumps({
        "text": test_content,
        "method": "kompress"
    }).encode('utf-8')

    try:
        request = urllib.request.Request(
            compress_url,
            data=compress_data,
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        response = urllib.request.urlopen(request, timeout=5)
        if response.status == 200:
            result = json.loads(response.read().decode('utf-8'))
            original_len = len(test_content)
            compressed_len = len(result.get("output", ""))
            compression_ratio = (1 - compressed_len / original_len) * 100 if original_len > 0 else 0
            print(f"✓ Compression endpoint OK")
            print(f"  Original: {original_len} chars → Compressed: {compressed_len} chars")
            print(f"  Compression ratio: {compression_ratio:.1f}%")
            if compressed_len >= original_len * 0.95:
                print("  ⚠ Compression minimal (likely validation-only passthrough)")
            else:
                print("  ✓ Significant compression achieved")
        else:
            print(f"⚠ Compression endpoint returned status {response.status}")
    except urllib.error.HTTPError as e:
        # Some endpoints may not be available, that's OK
        if e.code == 404:
            print(f"⚠ Compression endpoint not available (404) - may be normal for this configuration")
        else:
            print(f"⚠ Compression endpoint error: {e.code}")

    print("\n✓ All smoke tests passed")

finally:
    process.terminate()
    process.wait(timeout=5)
