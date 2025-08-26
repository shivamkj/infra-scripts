#!/bin/bash
set -euo pipefail

sudo systemctl stop postgresql
sleep 3

sudo -u postgres pgbackrest restore --stanza=main "$@" 2>&1

sudo systemctl start postgresql
