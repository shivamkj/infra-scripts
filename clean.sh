#!/bin/bash
set -euo pipefail

# Remove unused packages
sudo apt-get purge -y ufw

# Remove Snap and prevent it from reinstalling
sudo apt-get autoremove --purge -y snapd
sudo apt-mark hold snapd || true
cat <<EOF | sudo tee /etc/apt/preferences.d/nosnap.pref
# To prevent repository packages from triggering the installation of Snap,
# this file forbids snapd from being installed by APT.
# For more information: https://linuxmint-user-guide.readthedocs.io/en/latest/snap.html

Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
