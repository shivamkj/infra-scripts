FROM nginx:1.26.3-bookworm

ENV NGINX_VERSION     "1.26.3"
ENV NGINX_VTS_VERSION "0.2.3"

RUN apt-get update \
  && apt-get install -y --no-install-recommends gnupg2 lsb-release \
  && curl https://nginx.org/keys/nginx_signing.key \
  | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
  && echo "deb-src [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
  http://nginx.org/packages/debian `lsb_release -cs` nginx" > /etc/apt/sources.list.d/nginx.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends dpkg-dev curl \
  && mkdir -p /opt/rebuildnginx \
  && chmod 0777 /opt/rebuildnginx \
  && cd /opt/rebuildnginx \
  && su --preserve-environment -s /bin/bash -c "apt-get source nginx=${NGINX_VERSION}" _apt \
  && apt-get build-dep -y nginx=${NGINX_VERSION}

RUN cd /opt \
  && curl -sL https://github.com/vozlt/nginx-module-vts/archive/v${NGINX_VTS_VERSION}.tar.gz | tar -xz \
  && ls -al /opt/rebuildnginx \
  && ls -al /opt \
  && sed -i -r -e "s/\.\/configure(.*)/.\/configure\1 --add-module=\/opt\/nginx-module-vts-${NGINX_VTS_VERSION}/" /opt/rebuildnginx/nginx-${NGINX_VERSION}/debian/rules \
  && cd /opt/rebuildnginx/nginx-${NGINX_VERSION} \
  && dpkg-buildpackage -b \
  && cd /opt/rebuildnginx \
  && dpkg --install nginx_${NGINX_VERSION}-1~$(lsb_release -cs)_amd64.deb \
  && apt-get remove --purge -y dpkg-dev curl && apt-get -y --purge autoremove && rm -rf /var/lib/apt/lists/*

CMD ["nginx", "-g", "daemon off;"]
