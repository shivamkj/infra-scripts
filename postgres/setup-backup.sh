#!/bin/bash
set -euo pipefail

# Script to Setup PostgreSQL Backup

sudo apt-get install -y --no-install-recommends pgbackrest

# Setup Backup config
backupConfig=/etc/pgbackrest.conf
sudo cp postgres/pgbackrest.conf "$backupConfig"
sudo chmod -R 770 $backupConfig
sudo chown -R postgres:postgres $backupConfig

# Remove comments from config
sudo sed -i "/; .*/d" "$backupConfig"
sudo sed -i "/# .*/d" "$backupConfig"
  
# Update Backup config values
s3BucketName=""
s3BucketRegion=""
s3BucketEndpoint=""
s3BucketAccessKey=""
s3BucketSecretKey=""
s3Path=""
encryptPass=""
sudo sed -i "s|%%BUCKET_NAME%%|$s3BucketName" $backupConfig
sudo sed -i "s|%%BUCKET_ENDPOINT%%|$s3BucketEndpoint" $backupConfig
sudo sed -i "s|%%REGION%%|$s3BucketRegion" $backupConfig
sudo sed -i "s|%%ACCESS_KEY%%|$s3BucketAccessKey" $backupConfig
sudo sed -i "s|%%SECRET_KEY%%|$s3BucketSecretKey" $backupConfig
sudo sed -i "s|%%S3_PATH%%|$s3Path" $backupConfig
sudo sed -i "s|%%DB_PATH%%|/var/lib/postgresql/$PG_VERSION/main" $backupConfig
sudo sed -i "s|%%ENCRYPT_PASS%%|$encryptPass" $backupConfig

# Create required directories with proper permissions
sudo mkdir -p /tmp/pgbackrest
sudo chmod -R 770 /tmp/pgbackrest
sudo chown -R postgres:postgres /tmp/pgbackrest
# 
sudo mkdir -p /var/log/pgbackrest
sudo chmod -R 770 /var/log/pgbackrest
sudo chown -R postgres:postgres /var/log/pgbackrest

# Create a stanza for defining the cluster
sudo -u postgres pgbackrest stanza-create --stanza=main

# Update PostgreSQL configuration for backup
# Can also use alter SQL command to change config, ex. - "alter system set archive_mode = on"
pgConf=/etc/postgresql/$PG_VERSION/main/postgresql.conf
sudo sed -i "s|#archive_mode = [a-zA-Z0-9']\+|archive_mode = on" "$pgConf"
sudo sed -i "s|#archive_command = [a-zA-Z0-9']\+|archive_command = 'pgbackrest --stanza=main archive-push %p'" "$pgConf"
sudo sed -i "s|#wal_level = [a-zA-Z0-9']\+|wal_level = replica" "$pgConf"
sudo sed -i "s|#max_wal_senders = [a-zA-Z0-9']\+|max_wal_senders = 3" "$pgConf"

# Restart PostgreSQL for config changes to take effect
sudo systemctl restart postgresql
