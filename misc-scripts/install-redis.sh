#!/bin/bash
set -euo pipefail

curl -fsSL https://packages.redis.io/gpg |
  gpg --dearmor |
  sudo tee /usr/share/keyrings/redis-archive-keyring.gpg >/dev/null

sudo chmod u=rw,og=r /usr/share/keyrings/redis-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" |
  sudo tee /etc/apt/sources.list.d/redis.list

sudo apt-get update
sudo apt-get install -y --no-install-recommends redis

sudo systemctl enable --now redis-server.service
