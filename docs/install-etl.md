# Install and run the ETL

The commands below load every table definition and stored procedure in
dependency order. They use the local MariaDB client configuration: no password
or database environment name is stored in the repository.

Loading a SQL file replaces its procedure and creates its table when the table
does not already exist. It does **not** execute the ETL and does not modify raw
tables.

## Load all definitions

Copy the complete block, then enter the repository directory and target
database name when prompted.

```bash
read -erp "ETL repository directory: " ETL_REPOSITORY
cd "$ETL_REPOSITORY" || exit 1

read -rp "MariaDB database name: " ETL_DATABASE

mariadb --abort-source-on-error "$ETL_DATABASE" <<'MARIADB'
SOURCE etl/sql/gps_tidy.sql;
SOURCE etl/sql/myair_tidy.sql;
SOURCE etl/sql/smartwatchlow_tidy.sql;
SOURCE etl/sql/smartwatchhigh_tidy.sql;
SOURCE etl/sql/sleep_tidy.sql;

SOURCE etl/sql/gps_5min.sql;
SOURCE etl/sql/myair_5min.sql;
SOURCE etl/sql/smartwatchlow_5min.sql;
SOURCE etl/sql/smartwatchhigh_5min.sql;

SOURCE etl/sql/gps_hourly.sql;
SOURCE etl/sql/myair_hourly.sql;
SOURCE etl/sql/smartwatchlow_hourly.sql;
SOURCE etl/sql/smartwatchhigh_hourly.sql;

SOURCE etl/sql/gps_daily.sql;
SOURCE etl/sql/myair_daily.sql;
SOURCE etl/sql/smartwatchlow_daily.sql;
SOURCE etl/sql/smartwatchhigh_daily.sql;

SHOW PROCEDURE STATUS
WHERE Db = DATABASE()
  AND Name LIKE 'etl_%';
MARIADB
```

## Run the complete pipeline

Run this only after the definitions have loaded successfully. The order is
important: tidy tables are refreshed first, followed by five-minute, hourly
and daily tables. Sleep stops at its natural participant-night tidy layer.

```bash
read -rp "MariaDB database name: " ETL_DATABASE

mariadb "$ETL_DATABASE" <<'MARIADB'
CALL etl_gps_tidy();
CALL etl_myair_tidy();
CALL etl_smartwatchlow_tidy();
CALL etl_smartwatchhigh_tidy();
CALL etl_sleep_tidy();

CALL etl_gps_5min();
CALL etl_myair_5min();
CALL etl_smartwatchlow_5min();
CALL etl_smartwatchhigh_5min();

CALL etl_gps_hourly();
CALL etl_myair_hourly();
CALL etl_smartwatchlow_hourly();
CALL etl_smartwatchhigh_hourly();

CALL etl_gps_daily();
CALL etl_myair_daily();
CALL etl_smartwatchlow_daily();
CALL etl_smartwatchhigh_daily();
MARIADB
```

Each call prints its own row-count and timing summary. Stop and investigate if
MariaDB reports an error; later layers must not be run from a failed or stale
upstream layer.

After the definitions, target schemas and privileges have been verified, the
same calls can be run non-interactively by the nightly executable:

```bash
ETL_DATABASE=<database> ./etl/run_etl.sh
```

The executable stops at the first error and prevents overlapping runs. It
writes progress to standard output and standard error so the scheduler can
capture or mail the result.

## Existing incompatible tables

`CREATE TABLE IF NOT EXISTS` deliberately does not change an existing schema.
Therefore, loading the definitions is enough for absent or already compatible
tables, but it does not migrate an incompatible existing table. Such a managed
table must be deliberately removed and recreated before its procedure is
called. Do not drop raw source tables.
