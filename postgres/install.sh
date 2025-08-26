#!/bin/bash
set -euo pipefail

PG_VERSION=16

sudo apt-get install -y --no-install-recommends postgresql-common
sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
sudo apt-get install -y --no-install-recommends postgresql-$PG_VERSION
