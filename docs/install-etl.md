# Install and run

Requires MariaDB 10.11, the `mariadb` client, Bash and `flock`.
Configure credentials locally; do not pass passwords on the command line.
Check [permissions](database-permissions.md) and confirm the database/account
before installation or execution.

## Install definitions

Loading SQL creates absent tables and replaces procedures; it does not run the
ETL. `CREATE TABLE IF NOT EXISTS` does not migrate incompatible tables: any
schema replacement requires a separate, explicitly confirmed operation on the
named managed table. Never drop raw or mapping tables.

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

## Run

From the repository root, after installation succeeds:

```bash
ETL_DATABASE=your_database ./etl/run_etl.sh
```

| Option | Behavior |
|---|---|
| `ETL_DATABASE` or first argument | Target database; use only one form |
| `ETL_DEFAULTS_FILE` | Optional absolute path to an extra MariaDB client configuration |
| `ETL_LOCK_FILE` | Optional lock path; default `/tmp/trigger-etl-${UID}.lock` |

The runner executes tidy → five-minute → hourly → daily, stops on the first
error, and writes progress and procedure counts to stdout/stderr. The file lock
prevents overlapping runs sharing that lock; calls from other hosts or direct
SQL sessions must be coordinated separately. Lock contention exits with code 75.

For scheduling, adapt [crontab.example](../etl/crontab.example) and install it
with `crontab -e`. Its 02:00 schedule uses the server timezone.

## Failure and recovery

Investigate errors before running downstream layers. Transactional failures
preserve prior output; interrupted batched full builds may leave partial tidy
data that must be emptied before retrying. Confirm the exact target before any
cleanup. See [architecture](architecture.md#transactions-and-diagnostics).
