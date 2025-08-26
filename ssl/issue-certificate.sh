#!/bin/bash
set -euo pipefail

# Issue SSL certificate from LetsEncrypt with certbot and
# replace that certificate inside nginx config and reload nginx

domain=example.com
adminEmail=example@gmail.com

# Issue a new SSL certificate
sudo certbot certonly --webroot --non-interactive --agree-tos \
  -m "$adminEmail" \
  -w "/usr/share/nginx/html/$domain/" \
  -d "$domain"

# Update nginx config and reload
nginxConf=/etc/nginx/conf.d/$domain.conf
sudo sed -i "s|/etc/nginx/temp.crt;|/etc/letsencrypt/live/$domain/fullchain.pem;|g" "$nginxConf"
sudo sed -i "s|/etc/nginx/temp.key;|/etc/letsencrypt/live/$domain/privkey.pem;|g" "$nginxConf"
sudo nginx -t
sudo nginx -s reload
