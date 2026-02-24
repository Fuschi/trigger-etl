# trigger-etl

ETL scripts for the Trigger MariaDB database (bio4).

## Credentials
Scripts rely on `~/.my.cnf` (not stored in this repository).

Example:
[client]
host=bio4
port=3306
user=...
password=...
database=trigger

Permissions:
chmod 600 ~/.my.cnf

## Deploy SQL objects
etl/bin/deploy_sql.sh etl/sql/rebuild_myair_hourly.sql

## Run ETL
etl/bin/run_etl.sh

## Cron
See `etl/cron/example.cron`
