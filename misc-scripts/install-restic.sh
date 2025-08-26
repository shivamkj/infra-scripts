#!/bin/bash
set -euo pipefail

BINARY_URL=https://github.com/restic/restic/releases/download/v0.17.1/restic_0.17.1_linux_amd64.bz2
SHA_CHECKSUM=bdfaf16fe933136e3057e64e28624f2e0451dbd47e23badb2d37dbb60fdb6a70

binaryFile=../restic.bz2
curl -Lo "$binaryFile" "$BINARY_URL" --no-progress-meter

# Check sha256
echo "$SHA_CHECKSUM $binaryFile" | sha256sum -c

sudo apt-get install -y --no-install-recommends bzip2
bzip2 -df $binaryFile
binaryFile=../restic # Extracted Binary file path

sudo adduser --system --group --no-create-home --disabled-password \
	--shell /bin/false \
	restic

sudo chmod -R ug=rx,o= $binaryFile
sudo chown -R restic:restic $binaryFile
sudo mv $binaryFile /usr/local/bin/restic
