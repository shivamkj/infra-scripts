#!/bin/bash
set -euo pipefail

# Install Certot for issuing SSL certificate

sudo apt-get remove certbot
sudo apt-get install -y --no-install-recommends \
  python3 python3-venv

sudo python3 -m venv /opt/certbot/
sudo /opt/certbot/bin/pip install --upgrade pip
sudo /opt/certbot/bin/pip install certbot
sudo ln -sf /opt/certbot/bin/certbot /usr/bin/certbot
