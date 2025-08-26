#!/bin/bash
set -euo pipefail

# Builds latest version of podman from source on Ubuntu

# Install build dependencies
sudo apt update
sudo apt-get install -y --no-install-recommends \
  btrfs-progs \
  crun \
  git \
  golang-go \
  go-md2man \
  iptables \
  libassuan-dev \
  libbtrfs-dev \
  libc6-dev \
  libdevmapper-dev \
  libglib2.0-dev \
  libgpgme-dev \
  libgpg-error-dev \
  libprotobuf-dev \
  libprotobuf-c-dev \
  libseccomp-dev \
  libselinux1-dev \
  libsystemd-dev \
  make \
  netavark \
  pkg-config \
  uidmap \
  conmon \
  build-essential \
  runc

# Add configuration
sudo mkdir -p /etc/containers
sudo curl -Lo /etc/containers/registries.conf https://raw.githubusercontent.com/containers/image/main/registries.conf
sudo curl -Lo /etc/containers/policy.json https://raw.githubusercontent.com/containers/image/main/default-policy.json
sudo bash -c "echo 'unqualified-search-registries = [\"docker.io\"]' >> /etc/containers/registries.conf"

# Get Source Code & Build podman
git clone https://github.com/containers/podman/
cd podman
make BUILDTAGS = "" PREFIX =/usr
sudo make install PREFIX =/usr

# To run with crun, would need to build latest crun from source
podman run --network=host --security-opt=seccomp=unconfined --runtime runc busybox echo "hello world"

# For additional networking related dependencies
# sudo apt install - y--no - install - recommends slirp4netns passt
