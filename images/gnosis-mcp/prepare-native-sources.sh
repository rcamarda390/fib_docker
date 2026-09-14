#!/bin/sh
# Run in an empty build directory. Sources stay on the Trixie ABI when rebuilt.
set -eu

# Debian source archive SHA256 values come from each package's signed .dsc.
# util-linux 2.41.6 is the upstream stable security release; retain Trixie's
# 2.41.5 packaging instead of importing sid's debhelper 14 / libc requirements.
while read -r package archive checksum url; do
    mkdir -p "$package"
    curl --fail --location --silent --show-error --retry 3 "$url" -o "$archive"
    printf '%s  %s\n' "$checksum" "$archive" | sha256sum -c -
    case "$archive" in
        *.debian.tar.xz) tar --no-same-owner -xf "$archive" -C "$package" ;;
        *) tar --no-same-owner -xf "$archive" -C "$package" --strip-components=1 ;;
    esac
done <<'SOURCES'
attr attr.orig.tar.xz 6c8a2148a7b85043b68492bce43316b0e2e214fc4e628c7ede078e76e216330b https://deb.debian.org/debian/pool/main/a/attr/attr_2.6.0.orig.tar.xz
attr attr.debian.tar.xz b2a04e8170dbab934c5d43087deffeaa42168fdf3f31933ac28f62cb7995c6ab https://deb.debian.org/debian/pool/main/a/attr/attr_2.6.0-1.debian.tar.xz
acl acl.orig.tar.xz e661131456d2708a01c614a0f400e11d7d1bfaeb6f3e74b75bb980b72f0161a3 https://deb.debian.org/debian/pool/main/a/acl/acl_2.4.0.orig.tar.xz
acl acl.debian.tar.xz 65931c2fb3e821bda67f8d8d72d77e99ac61502748dcdf38b6805fe89339085e https://deb.debian.org/debian/pool/main/a/acl/acl_2.4.0-1.debian.tar.xz
ncurses ncurses.orig.tar.gz e280541f4f601b8586bec305976c873fd641607f9bc4254bf661034dcccac4e9 https://deb.debian.org/debian/pool/main/n/ncurses/ncurses_6.6+20251231.orig.tar.gz
ncurses ncurses.debian.tar.xz fd4a1fd7113e034175310bda8f4589854a0f66fe70482a6bd553de73d773303c https://deb.debian.org/debian/pool/main/n/ncurses/ncurses_6.6+20251231-1.debian.tar.xz
util-linux util-linux.orig.tar.xz e596083744e746be7d2823b62b43f4418dd7bf56303b4dc09e6fe8112fe3d7ed https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.41/util-linux-2.41.6.tar.xz
util-linux util-linux.debian.tar.xz 5b327ccd22f0f4ed28a389870aa51d04ecedb8693e52a1d122850f2b3188cbf6 https://deb.debian.org/debian/pool/main/u/util-linux/util-linux_2.41.5-0+deb13u1.debian.tar.xz
SOURCES

# These two Trixie backports are already in 2.41.6. Prove that before removing
# them from the series; retain every other Debian patch and packaging rule.
(
    cd util-linux
    for patch in \
        upstream/loopdev-use-openat2-RESOLVE_NO_SYMLINKS-for-backing-file.patch \
        upstream/libmount-restrict-source-path-canonicalization-for-non-ro.patch; do
        git apply --reverse --check "debian/patches/$patch"
        grep -Fx "$patch" debian/patches/series
        sed -i "\|^${patch}$|d" debian/patches/series
    done
)

for entry in attr:1:2.6.0-1 acl:2.4.0-1 ncurses:6.6+20251231-1 util-linux:2.41.6-0; do
    package=${entry%%:*}
    version=${entry#*:}
    changelog="$package/debian/changelog"
    {
        printf '%s (%s+rcamarda1) trixie; urgency=high\n\n' "$package" "$version"
        printf '  * Rebuild fixed upstream sources for the Gnosis Trixie runtime.\n\n'
        printf ' -- rcamarda390 image build <rcamarda390@users.noreply.github.com>  Mon, 14 Sep 2026 00:00:00 +0000\n\n'
        cat "$changelog"
    } > "$changelog.new"
    mv "$changelog.new" "$changelog"
    dpkg-source --before-build "$package"
done
