#!/bin/bash
set -e

NODEJS_PREBUILT_BINARIES="https://nodejs.org/dist/v20.17.0/node-v20.17.0-linux-x64.tar.xz"
NODEJS_PATH="/usr/local/nodejs"

# Install NodeJS
curl -o nodejs.tar.xz $NODEJS_PREBUILT_BINARIES
mkdir -p nodejs && tar -xf nodejs.tar.xz -C nodejs --strip-components=1
sudo rm -rf $NODEJS_PATH
sudo mv nodejs $NODEJS_PATH && rm nodejs.tar.xz
echo "PATH=\"$NODEJS_PATH/bin:\$PATH\"" >>~/.bashrc
source ~/.bashrc

# Clone Repo
read -rp "Enter Git Repo Url:" GIT_URL
echo -n Git Token Key: 
read -rs GITHUB_TOKEN
SCRIPT_DIR=$(echo "$GIT_URL" | sed -E 's/.*\/([^\/]+)\.git/\1/')
# Clone git repo with scripts
git config --global url."https://$GITHUB_TOKEN@github.com/".insteadOf "https://github.com/"
rm -rf ./"$SCRIPT_DIR"
git clone "$GIT_URL" ./"$SCRIPT_DIR"
cd ./"$SCRIPT_DIR"
