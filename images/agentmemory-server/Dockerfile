# agentmemory-server bundles agentmemory and its compatible iii engine in one
# image, matching upstream's own single-container deploy pattern (see
# rohitg00/agentmemory deploy/{fly,railway,render,coolify}/Dockerfile): the
# iii binary is copied in from the official iiidev/iii image, and the
# `agentmemory` CLI (not the raw dist/index.mjs server entry) is run as the
# container's main process. The CLI finds `iii` on PATH, spawns it itself,
# and only then starts its own REST/MCP-HTTP server -- there is no separate
# iii-engine container or service to wire up.
#
# iii is pinned to 0.11.2 because that is the exact version agentmemory
# 0.9.28 pins for its `iii-sdk` client dependency. iii-sdk 0.11.6 changed
# engine routing and broke agentmemory's REST mount (upstream issue #555,
# fixed by pinning back in PR #567) -- newer iii releases are not
# drop-in compatible, so this version must track agentmemory's own pin
# rather than the latest iii release.
#
# agentmemory 0.9.29 is not used here even though it is referenced in
# upstream's own deploy Dockerfiles: as of this build it has a CHANGELOG
# entry and a bumped package.json on the upstream main branch, but was never
# published to npm (no 0.9.29 tag, registry lookup 404s). Pinning to it would
# make this Dockerfile fail at `npm ci`. Re-pin once npm actually has it.
ARG III_VERSION=0.11.2
ARG AGENTMEMORY_VERSION=0.9.28
ARG AGENTMEMORY_IMAGE_VERSION=v1

# Digest-pinned so the iii binary this image ships is exactly the one
# verified against agentmemory's pin, not whatever 0.11.2 is retagged to.
FROM iiidev/iii:${III_VERSION}@sha256:15f8d4ed16c0bec350b98f4e18ed04498b1fc5ccc50585e087b736717300cf26 AS iii-image

FROM node:26-trixie-slim AS npm-install
ARG AGENTMEMORY_VERSION
WORKDIR /opt/agentmemory
COPY package.json package-lock.json ./
RUN npm ci --no-fund \
 && test "$(node -p "require('./package.json').dependencies['@agentmemory/agentmemory']")" = "$AGENTMEMORY_VERSION"

# agentmemory 0.9.28 still resolves local embeddings through
# @xenova/transformers (the @huggingface/transformers v4 migration lands in
# the unreleased 0.9.29 line -- see the version note above). Pre-warming the
# cache here means the runtime never touches the network for the embedding
# model.
FROM npm-install AS model-cache
ENV XENOVA_CACHE_DIR=/opt/agentmemory/model-cache
COPY cache-models.js /opt/agentmemory/cache-models.js
RUN node /opt/agentmemory/cache-models.js

FROM node:26-trixie-slim AS production
ARG AGENTMEMORY_VERSION
ARG III_VERSION
ARG AGENTMEMORY_IMAGE_VERSION
LABEL org.opencontainers.image.title="agentmemory-server" \
      org.opencontainers.image.version="${AGENTMEMORY_VERSION}-${AGENTMEMORY_IMAGE_VERSION}" \
      org.opencontainers.image.description="Self-contained agentmemory + iii engine image for air-gapped deployments" \
      agentmemory.version="${AGENTMEMORY_VERSION}" \
      agentmemory.iii-version="${III_VERSION}" \
      agentmemory.image-version="${AGENTMEMORY_IMAGE_VERSION}"
# Trixie supplies a fixed zlib package for CVE-2023-45853. The glibc findings
# CVE-2026-5435, CVE-2026-5450, and CVE-2026-5928 are still open against
# debian:trixie libc6/libc-bin -- Debian's security tracker carries all three
# as <no-dsa> "Minor issue" for trixie (no point release planned).
# CVE-2026-5450 and CVE-2026-5928 are fixed upstream starting in glibc 2.42
# (forky/sid); CVE-2026-5435 has no upstream fix at all yet. Either way
# `apt-get upgrade` below cannot clear them and glibc cannot be removed from
# a dynamically linked Node runtime.
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends ca-certificates gosu openssl tini \
 && (apt-get purge -y --auto-remove --allow-remove-essential perl-base perl-modules-5.40 || echo "perl purge skipped: not removable in this base image") \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/agentmemory
COPY --from=npm-install /opt/agentmemory/package.json ./package.json
COPY --from=npm-install /opt/agentmemory/package-lock.json ./package-lock.json
COPY --from=npm-install /opt/agentmemory/node_modules ./node_modules
COPY --from=model-cache /opt/agentmemory/model-cache ./model-cache
COPY --from=iii-image /app/iii /usr/local/bin/iii
COPY iii-config.yaml /opt/agentmemory/iii-config.yaml
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod 0755 /usr/local/bin/docker-entrypoint.sh /usr/local/bin/iii \
 && ln -s /opt/agentmemory/node_modules/.bin/agentmemory /usr/local/bin/agentmemory \
 && mkdir -p /data /opt/agentmemory/model-cache \
 && chown -R node:node /data /opt/agentmemory/model-cache
ENV NODE_ENV=production \
    HOME=/home/node \
    XENOVA_CACHE_DIR=/opt/agentmemory/model-cache \
    TRANSFORMERS_OFFLINE=1 \
    HF_HUB_OFFLINE=1 \
    AGENTMEMORY_III_VERSION=${III_VERSION} \
    AGENTMEMORY_III_CONFIG=/opt/agentmemory/iii-config.yaml \
    AGENTMEMORY_SECRET_FILE=/data/.agentmemory-secret \
    TINI_SUBREAPER=1
# Everything above is built against an intact system; the image is stripped here
# and immediately re-verified below.
#
# Each Debian finding this image carries is published with no fixed version, so
# the `apt-get upgrade` above cannot clear them. None of these packages is
# reachable from the runtime path, so they are dropped outright:
#   gzip           CVE-2026-41992 -- node links zlib statically; nothing shells
#                                    out to gzip and nothing untars at runtime
#   ncurses-bin    CVE-2025-69720 -- one CVE in the ncurses source package, so
#   ncurses-base                      all three binary packages carry it and
#   libtinfo6                         purging only ncurses-bin leaves it behind.
#                                     bash is the only thing linking
#                                     libtinfo.so.6 and this image never runs
#                                     bash -- the entrypoint is dash and CMD
#                                     execs the agentmemory CLI directly
#   libacl1        CVE-2026-54369 -- only cp/mv/install/tar link libacl.so.1;
#   libattr1       CVE-2026-54371    the entrypoint uses mkdir/chown/cat, which
#                                    link neither
#   libsqlite3-0   CVE-2026-11822 -- the node binary bundles SQLite; its NEEDED
#                  CVE-2026-11824    list is libatomic/libstdc++/libgcc_s/libc
#   bsdutils       CVE-2026-53615 -- the util-linux family, an integer overflow
#   libblkid1                         in libblkid partition parsing. Nothing
#   liblastlog2-2                     here mounts filesystems, reads partition
#   libmount1                         tables or logs in; gosu needs none of it,
#   libsmartcols1                     and neither libvips (sharp) nor
#   libuuid1                          onnxruntime name any of these in NEEDED.
#   login                             Costs the image su/mount/logger, which it
#   mount                             has no runtime use for.
#   util-linux
#   libpam0g       CVE-2025-8941  -- one CVE tracked against the pam source
#   libpam-modules                    package (same pattern as ncurses
#   libpam-runtime                    above), so all three binary packages
#                                     carry it even though the vulnerable
#                                     code (pam_namespace) ships only in
#                                     libpam-modules. Nothing here
#                                     authenticates through PAM; gosu drops
#                                     privileges with plain setuid/setgid,
#                                     and user lookup goes through glibc
#                                     NSS, not PAM. libpam0g's own Depends
#                                     are debconf, libaudit1 and libc6 --
#                                     nothing in this image links
#                                     libpam.so.0.
# dpkg is used rather than `apt-get purge --auto-remove` because gzip and
# ncurses-bin are Essential and apt would cascade. No apt operations run after
# this layer, so the unsatisfied dependencies are inert.
#
# libpam-modules needs both halves of this next step. apt cannot do it:
# util-linux PreDepends on libpam-modules, and apt will not break a
# PreDepends, so it re-selects the package for install and declines. dpkg can
# force past that -- util-linux and login are on this very line -- but its
# postrm execs /usr/share/debconf/frontend, and the perl-base purge above
# cascades into debconf, so the script exits 127 and fails the build. The
# stub below satisfies the exec so the purge completes and dpkg records it as
# such. Skipping that cleanup is harmless: it exists to drop the package's
# entries from the debconf database, which was itself deleted a layer ago.
# dpkg removes the package's files either way -- the maintainer script only
# tidies external state.
RUN mkdir -p /usr/share/debconf \
 && printf '#!/bin/sh\nexit 0\n' > /usr/share/debconf/frontend \
 && chmod 0755 /usr/share/debconf/frontend \
 && dpkg --purge --force-depends --force-remove-essential --force-remove-protected \
      gzip ncurses-bin ncurses-base libtinfo6 libacl1 libattr1 libsqlite3-0 \
      bsdutils libblkid1 liblastlog2-2 libmount1 libsmartcols1 libuuid1 \
      login mount util-linux libpam-runtime libpam-modules libpam0g \
 && rm -rf /usr/share/debconf \
 && ! dpkg-query -W -f='${Status}' libpam-modules 2>/dev/null | grep -q 'install ok installed' \
 && ! dpkg-query -W -f='${Status}' libpam0g 2>/dev/null | grep -q 'install ok installed'
# brace-expansion 5.0.7 (CVE-2026-14257, CVE-2026-69152) and ip-address 10.2.0
# (CVE-2026-69192) enter the image only through the npm that ships inside the
# node base image -- this project's own lockfile pins neither, and resolves
# ip-address to 10.4.0. Current npm releases still bundle both vulnerable
# versions, so upgrading npm does not help. Nothing in the runtime needs a
# package manager: the entrypoint execs the agentmemory CLI directly against
# the node_modules tree copied in above.
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
      /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
      /opt/yarn-v* /usr/local/bin/yarn /usr/local/bin/yarnpkg \
      /root/.npm
# Prove the package removals above did not cut into anything this image needs.
# The first half walks the exact syscall path docker-entrypoint.sh takes --
# mkdir/chown/cat from coreutils, openssl for the HMAC secret, tini as PID 1,
# and gosu dropping to node:node before exec'ing the CLI -- then loads the
# two native addons, since sharp pulls in libvips and onnxruntime-node pulls in
# libonnxruntime, and those are what a careless purge would break first.
#
# It then imports iii-sdk and the MCP SDK's streamableHttp entry, since the
# CLI's server path drags in the whole OpenTelemetry graph and hono
# respectively -- the same dependency graph a package.json override could
# silently break. Last, it confirms the iii binary this build copied in
# actually runs and reports the pinned version, since a bad digest or a
# COPY path change would otherwise only surface at container startup.
#
# The final block fails the build if a purge ever silently degrades into a
# no-op and quietly reintroduces the findings. perl is deliberately absent
# from that list: the purge above tolerates a base image where it is not
# removable.
RUN set -eu \
 && verify_dir=/tmp/agentmemory-verify \
 && mkdir -p "$verify_dir" \
 && chown -R node:node "$verify_dir" \
 && openssl rand -hex 32 > "$verify_dir/secret" \
 && test -n "$(cat "$verify_dir/secret")" \
 && test -x /usr/bin/tini \
 && gosu node:node node -e "console.log('agentmemory runtime path OK')" \
 && cd /opt/agentmemory \
 && gosu node:node node -e "require('@opentelemetry/propagator-b3')" \
 && gosu node:node node -e "require('sharp')" \
 && gosu node:node node -e "require('onnxruntime-node')" \
 && gosu node:node node -e "require('iii-sdk')" \
 && gosu node:node node -e "require('@modelcontextprotocol/sdk/server/streamableHttp.js')" \
 && gosu node:node /usr/local/bin/iii --version | grep -qx "$III_VERSION" \
 && rm -rf "$verify_dir" \
 && for removed in npm npx corepack gzip tput su mount; do \
      if command -v "$removed" >/dev/null 2>&1; then \
        echo "ERROR: $removed survived removal; scan findings would regress" >&2; \
        exit 1; \
      fi; \
    done
VOLUME ["/data"]
EXPOSE 3111
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/docker-entrypoint.sh"]
