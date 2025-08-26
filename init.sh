#!/bin/bash
set -euo pipefail

# Update System
sudo apt-get update
sudo apt-get upgrade -y

# Install some basic tools
sudo apt-get install -y --no-install-recommends \
  curl

# Run cleanup
# bash cleanup.sh

# Security
# 1. Setup Firewall
# 2. Setup Fail2Ban
