# syntax=docker/dockerfile:1.7

ARG NGINX_VERSION=1.31.4
ARG NGINX_COMMIT=39ffdd8ece695aeb3874c7d3eaf863dc64e82482

FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40 AS builder
ARG NGINX_VERSION
ARG NGINX_COMMIT

RUN apk upgrade --no-cache \
    && apk add --no-cache \
       build-base \
       ca-certificates \
       git \
       linux-headers \
       openssl-dev \
       pcre2-dev \
       zlib-dev \
    && git clone --depth 1 --branch "release-${NGINX_VERSION}" \
       https://github.com/nginx/nginx.git /src \
    && test "$(git -C /src rev-parse HEAD)" = "$NGINX_COMMIT"

WORKDIR /src
RUN auto/configure \
      --prefix=/usr/local/nginx \
      --with-compat \
      --with-file-aio \
      --with-threads \
      --with-http_ssl_module \
      --with-http_v2_module \
      --with-http_realip_module \
      --with-http_auth_request_module \
      --with-http_stub_status_module \
      --with-http_gzip_static_module \
      --with-http_gunzip_module \
      --with-stream \
      --with-stream_ssl_module \
    && make -j"$(getconf _NPROCESSORS_ONLN)" \
    && make install DESTDIR=/out \
    && test -x /out/usr/local/nginx/sbin/nginx

FROM alpine:3.23.5@sha256:fd791d74b68913cbb027c6546007b3f0d3bc45125f797758156952bc2d6daf40
ARG NGINX_VERSION
ARG NGINX_COMMIT

RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates openssl pcre2 zlib \
    && addgroup -S nginx \
    && adduser -S -D -H -G nginx nginx

COPY --from=builder /out/usr/local/nginx/ /usr/local/nginx/

RUN mkdir -p \
      /usr/local/nginx/logs \
      /usr/local/nginx/client_body_temp \
      /usr/local/nginx/proxy_temp \
      /usr/local/nginx/fastcgi_temp \
      /usr/local/nginx/uwsgi_temp \
      /usr/local/nginx/scgi_temp \
    && ln -sf /dev/stdout /usr/local/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/nginx/logs/error.log \
    && /usr/local/nginx/sbin/nginx -t \
    && test "$(/usr/local/nginx/sbin/nginx -v 2>&1)" = "nginx version: nginx/${NGINX_VERSION}"

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1

LABEL org.opencontainers.image.title="nginx" \
      org.opencontainers.image.description="NGINX mainline built from the upstream nginx/nginx source release" \
      org.opencontainers.image.source="https://github.com/nginx/nginx" \
      org.opencontainers.image.licenses="BSD-2-Clause" \
      org.opencontainers.image.version="${NGINX_VERSION}" \
      org.opencontainers.image.revision="${NGINX_COMMIT}"

STOPSIGNAL SIGQUIT
ENTRYPOINT ["/usr/local/nginx/sbin/nginx"]
CMD ["-g", "daemon off;"]
