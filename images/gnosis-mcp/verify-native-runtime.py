"""Fail the image build if native security upgrades or their callers break."""

import ctypes
import ctypes.util
import gzip
from pathlib import Path
import subprocess
import tempfile
import uuid
import zlib


floors = {
    "acl": "2.4.0-1",
    "attr": "1:2.6.0-1",
    "ncurses": "6.6+20260608-2",
    "util-linux": "2.41.6-0",
}
required = {"libacl1", "libattr1", "ncurses-bin", "libuuid1", "util-linux"}
rows = subprocess.check_output(
    ["dpkg-query", "-W", "-f=${Package}\t${db:Status-Status}\t${source:Package}\t${source:Version}\n"],
    text=True,
)
for row in rows.splitlines():
    package, status, source, version = row.split("\t")
    if status != "installed":
        continue
    required.discard(package)
    if source in floors:
        subprocess.run(["dpkg", "--compare-versions", version, "ge", floors[source]], check=True)
        print(f"Verified {package}: {source} {version}")
assert not required, f"Required packages missing: {sorted(required)}"

# Exercise real dynamically loaded modules. zlib is retained: CVE-2026-85091
# has no confirmed Debian fix, and Python depends on this library.
import _uuid

assert len(_uuid.generate_time_safe()[0]) == 16
assert uuid.uuid4().version == 4
payload = b"gnosis native runtime check\n" * 100
assert zlib.decompress(zlib.compress(payload)) == payload
assert gzip.decompress(gzip.compress(payload)) == payload
for library in ("acl", "attr", "uuid", "mount", "blkid", "smartcols"):
    path = ctypes.util.find_library(library)
    assert path, f"Missing library: {library}"
    ctypes.CDLL(path)

# ACL 2.4 adds symbols that can collide with older tar callers. Exercise tar's
# ACL path and coreutils copying as the final non-root application user.
with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    source = root / "source"
    source.write_bytes(payload)
    subprocess.run(["cp", "--preserve=all", str(source), str(root / "copy")], check=True)
    assert (root / "copy").read_bytes() == payload
    subprocess.run(["tar", "--acls", "--xattrs", "-cf", str(root / "test.tar"), "-C", directory, "source"], check=True)
    source.unlink()
    subprocess.run(["tar", "--acls", "--xattrs", "-xf", str(root / "test.tar"), "-C", directory], check=True)
    assert source.read_bytes() == payload
subprocess.run(["infocmp", "xterm"], check=True, stdout=subprocess.DEVNULL)
print("Native runtime verification passed")
