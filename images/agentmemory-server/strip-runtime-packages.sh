#!/bin/sh

set -eu

runtime_root=${1:?runtime root is required}
if [ "$runtime_root" != /runtime-root ]; then
    echo "refusing unexpected runtime root: $runtime_root" >&2
    exit 1
fi

admindir="$runtime_root/var/lib/dpkg"
test -f "$admindir/status"

package_state() {
    dpkg-query --admindir="$admindir" -W -f='${db:Status-Status}' "$1" 2>/dev/null || true
}

# The published 0.9.29-v5 package database proves that dpkg is tar's only
# installed reverse dependency. Remove the package manager and tar together;
# removing tar alone would leave a broken dpkg installation.
dpkg_dependencies=$(dpkg-query --admindir="$admindir" -W -f='${Depends}' dpkg)
printf '%s\n' "$dpkg_dependencies" | grep -Eq '(^|, )[[:space:]]*tar([[:space:](,]|$)'

for package in apt libapt-pkg7.0 debian-archive-keyring sqv dpkg tar gzip; do
    test "$(package_state "$package")" = installed
done

# Perl was removed after all apt/npm work in the source root. Keep a minimal
# debconf stub available while package maintainer scripts run in the copied
# root, without changing the intact build root.
test ! -e "$runtime_root/usr/share/debconf/frontend"
mkdir -p "$runtime_root/usr/share/debconf"
printf '#!/bin/sh\nexit 0\n' > "$runtime_root/usr/share/debconf/frontend"
chmod 0755 "$runtime_root/usr/share/debconf/frontend"

# Operate on the copied root with the build root's dpkg executable. This lets
# dpkg remove itself last without damaging the build environment used to
# validate the candidate. The final scratch stage receives only this root.
dpkg --root="$runtime_root" --purge --force-depends --force-remove-essential \
    --force-remove-protected apt libapt-pkg7.0 debian-archive-keyring sqv
dpkg --root="$runtime_root" --purge --force-depends --force-remove-essential \
    --force-remove-protected libsystemd0 libudev1 libpcre2-8-0
dpkg --root="$runtime_root" --purge --force-depends --force-remove-essential \
    --force-remove-protected tar gzip
dpkg --root="$runtime_root" --purge --force-depends --force-remove-essential \
    --force-remove-protected dpkg

rm -f "$runtime_root/usr/share/debconf/frontend"

for package in apt libapt-pkg7.0 debian-archive-keyring sqv dpkg tar gzip \
               libsystemd0 libudev1 libpcre2-8-0 perl-base curl; do
    state=$(package_state "$package")
    test "$state" != installed || {
        echo "$package is still installed in the runtime root" >&2
        exit 1
    }
done

for path in usr/bin/apt usr/bin/dpkg usr/bin/dpkg-query usr/bin/tar \
            usr/bin/gzip usr/bin/curl usr/bin/perl; do
    test ! -e "$runtime_root/$path" || {
        echo "$path is still present in the runtime root" >&2
        exit 1
    }
done

chroot "$runtime_root" /sbin/ldconfig
chroot "$runtime_root" /usr/local/bin/pcre2grep -V \
    | grep -F 'pcre2grep version 10.48'

for binary in /bin/sh /usr/bin/openssl /usr/bin/tini /usr/sbin/gosu \
              /usr/local/bin/node /usr/local/bin/iii /usr/bin/chown \
              /usr/bin/chmod /usr/bin/mkdir; do
    test -x "$runtime_root$binary"
    ! chroot "$runtime_root" /usr/bin/ldd "$binary" 2>&1 | grep -q 'not found'
done

chroot "$runtime_root" /usr/bin/openssl rand -hex 32 \
    | grep -Eq '^[0-9a-f]{64}$'
chroot "$runtime_root" /usr/sbin/gosu node:node /usr/local/bin/node \
    -e "require('node:zlib').gzipSync('runtime dependency check'); console.log('node runtime OK')"
chroot "$runtime_root" /usr/local/bin/node --input-type=module \
    -e "await import('iii-sdk'); console.log('iii-sdk runtime OK')"
chroot "$runtime_root" /usr/bin/env \
    TRANSFORMERS_MODEL_PATH=/opt/agentmemory/models \
    TRANSFORMERS_CACHE_DIR=/opt/agentmemory/transformers-cache \
    TRANSFORMERS_OFFLINE=1 \
    HF_HUB_OFFLINE=1 \
    NODE_OPTIONS=--import=/opt/agentmemory/transformers-offline.mjs \
    /usr/local/bin/agentmemory-entrypoint.sh --offline-embedding-test
