#!/bin/bash
set -euo pipefail

sudo apt-get install -y --no-install-recommends fail2ban

# Update config for blocking SSH
sudo cp security/fail2ban.sshd.conf /etc/fail2ban/jail.d/sshd.conf
sudo sed -i "s|mode =.*|mode = aggressive" /etc/fail2ban/filter.d/sshd.conf
sudo systemctl restart fail2ban
