# Command to export schema
DB_NAME="default"
DB_USER="default"
clickhouse-client -d "$DB_NAME" -u "$DB_USER" --query "SHOW TABLES" --format TSVRaw | while IFS=$'\t' read -r table; do
  echo "-- Table: $table"
  clickhouse-client -d "$DB_NAME" -u "$DB_USER" --query "SHOW CREATE TABLE $table" --format TSVRaw
  echo
done > schema_export.sql
