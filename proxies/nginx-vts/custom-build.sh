#!/bin/bash
set -euo pipefail

./configure \
  --with-cc-opt='-g -O2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -flto=auto -ffat-lto-objects -fstack-protector-strong -fstack-clash-protection -Wformat -Werror=format-security -fcf-protection -fPIC -ffile-prefix-map=/build/nginx/nginx-1.26.0=. -fdebug-prefix-map=/build/nginx/nginx-1.26.0=/usr/src/nginx-1.26.0 -Wdate-time -D_FORTIFY_SOURCE=3' \
  --with-ld-opt='-Wl,-Bsymbolic-functions -flto=auto -ffat-lto-objects -Wl,-z,relro -Wl,-z,now -Wl,--as-needed -fPIC' \
  --user=nginx \
  --group=nginx \
  --prefix=/etc/nginx \
  --modules-path=/usr/lib/nginx/modules \
  --conf-path=/etc/nginx/nginx.conf \
  --sbin-path=/usr/sbin/nginx \
  --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
  --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
  --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
  --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
  --error-log-path=/var/log/nginx/error.log \
  --http-log-path=/var/log/nginx/access.log \
  --http-client-body-temp-path=/var/cache/nginx/client_temp \
  --lock-path=/var/run/nginx.lock \
  --pid-path=/var/run/nginx.pid \
  --with-compat \
  --with-file-aio \
  --with-http_ssl_module \
  --with-threads \
  --with-http_v2_module \
  --with-stream_ssl_module \
  --with-mail_ssl_module \
  --with-stream_ssl_preread_module \
  --with-http_gunzip_module \
  --with-http_gzip_static_module \
  --with-http_dav_module \
  --with-http_auth_request_module \
  --with-http_stub_status_module \
  --with-http_realip_module \
  --with-stream_realip_module \
  --with-http_slice_module \
  --with-http_secure_link_module \
  --with-http_sub_module \
  --with-http_random_index_module \
  --with-http_addition_module \
  --with-http_mp4_module \
  --with-http_flv_module \
  --with-stream=dynamic \
  --with-mail=dynamic \
  --with-http_v3_module

# --with-pcre-jit \