#!/bin/bash
set -e

# PACKAGE_URL="https://github.com/prometheus/prometheus/releases/download/v2.45.3/prometheus-2.45.3.linux-amd64.tar.gz"
# VERSION="2.45.3"
# SUM="53b23de673c54bf6eeac13f17fe14027e8fe7800d0cf361e3177ba96413812b8"

PACKAGE_URL="https://github.com/prometheus/prometheus/releases/download/v2.49.1/prometheus-2.49.1.linux-amd64.tar.gz"
VERSION="2.49.1"
SUM="93460f66d17ee70df899e91db350d9705c20b1576800f96acbd78fa004e7dc07"

PACKAGE_FILE="prometheus.tar.gz"
EXTRACT_PATH="prometheus/"

download_package() {
	echo "Downloading Package"
	curl -Lo $PACKAGE_FILE $PACKAGE_URL --no-progress-meter
	if ! echo "$SUM $PACKAGE_FILE" | sha256sum -c; then
		echo "Checksum failed" >&2 && exit 1
	fi
	mkdir $EXTRACT_PATH
	echo "Extracting Package"
	tar -xf $PACKAGE_FILE -C $EXTRACT_PATH --strip-components 1
}

install_package() {
	sudo useradd --system --no-create-home --shell /bin/false prometheus || echo "User already exists."
	cd $EXTRACT_PATH || exit 1

	# move binary
	sudo mv prometheus promtool /usr/local/bin/
	sudo chown prometheus:prometheus /usr/local/bin/prom*

	# create directory for saving prometheus data
	sudo mkdir /etc/prometheus/ /mnt/prometheus/
	sudo chown -R prometheus:prometheus /etc/prometheus/ /mnt/prometheus/

	cd .. && rm -rf $EXTRACT_PATH $PACKAGE_FILE

	sudo cp -f ./monitering/config/prometheus.yaml /etc/prometheus/prometheus.yaml
	sudo cp -f ./monitering/config/prometheus.service.ini /etc/systemd/system/prometheus.service
}

update_binary() {
	echo "Updating/Downgrading Package"
	cd $EXTRACT_PATH || exit 1
	sudo systemctl stop prometheus

	# move new binary
	sudo mv prometheus promtool /usr/local/bin/
	sudo chown prometheus:prometheus /usr/local/bin/prom*

	sudo systemctl enable --now prometheus
	echo "Package Upgraded/Downgraded successfully"
	cd .. && rm -rf $EXTRACT_PATH $PACKAGE_FILE
}

# Check if Prometheus is installed with correct version, else take required steps
if which prometheus >/dev/null 2>&1; then
	INSTALLED_VERSION=$(prometheus --version | awk 'NR==1{print $3}')
	echo "Installed Prometheus version: $INSTALLED_VERSION"
	if [ "$INSTALLED_VERSION" == $VERSION ]; then
		echo "Prometheus is installed with correct version"
		sudo systemctl enable --now prometheus
	else
		echo "Package Update/Downgrade required"
		download_package
		update_binary
	fi
else
	echo "Prometheus is not installed."
fi
