#!/bin/bash
set -euo pipefail

# Creates Postgres database if not exists
dbName=test_db
echo "SELECT 'CREATE DATABASE $dbName' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$dbName')\gexec" |
   sudo -u postgres psql

# Creates User if not exists and also grant access to the database for this created user
userName=test_user
password=random_pass_123
dbName=test_db

sudo -u postgres psql -c """
DO
\$BLOCK\$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = '$userName') THEN

      RAISE NOTICE 'Role $userName already exists. Skipping.';
   ELSE
      BEGIN -- nested block
         CREATE ROLE $userName WITH LOGIN ENCRYPTED PASSWORD '$password';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role $userName was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
\$BLOCK\$;
"""

# Grant permission to user to access
sudo -u postgres psql -d "$dbName" -c "GRANT ALL PRIVILEGES ON DATABASE $dbName TO $userName"
sudo -u postgres psql -d "$dbName" -c "GRANT ALL ON SCHEMA public TO \"$userName\";"
