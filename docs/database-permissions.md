# Database permissions and safety model

## Purpose

This document defines the privileges required to inspect, install and run the
TRIGGER ETL while keeping raw sensor data read only.

Database names, hosts and account names are runtime configuration and must not
be committed. Replace these placeholders locally:

```text
<database>  target database
<owner>     account that installs table and procedure definitions
<runner>    account that calls the installed procedures
<host>      allowed client host
```

The safety boundary is:

- raw and mapping tables may be read but never modified by this project;
- only the ETL-managed tables and routines listed below may be created or
  changed;
- privileges are separated between definition installation and routine
  execution when operationally practical;
- the exact target database and effective account are checked before any DDL
  or destructive managed-table operation.

## Managed and source objects

The ETL owns these persistent output tables:

```text
gps_tidy                 gps_5min                 gps_hourly                 gps_daily
myair_tidy               myair_5min               myair_hourly               myair_daily
smartwatchlow_tidy       smartwatchlow_5min       smartwatchlow_hourly       smartwatchlow_daily
smartwatchhigh_tidy      smartwatchhigh_5min      smartwatchhigh_hourly      smartwatchhigh_daily
sleep_tidy
```

Each table has a parameterless procedure named `etl_<table>`, for example
`etl_gps_tidy` and `etl_gps_daily`.

The read-only source boundary consists of:

```text
gps                 user_gps
myair               user_myair
smartwatchlow       user_smartwatchlow
smartwatchhigh      user_smartwatchhigh
sleep               user_sleep
```

No procedure issues `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `ALTER` or
`DROP` against a source or mapping table.

## Privileges by activity

### Read-only design and validation

Schema-wide `SELECT` is the simplest way to inspect schemas, distributions and
output counts:

```sql
GRANT SELECT
ON `<database>`.*
TO '<owner>'@'<host>';
```

Grant `SHOW VIEW` only if views must be inspected. No global administrative
privilege is required.

### Installing definitions

The SQL files execute `CREATE TABLE IF NOT EXISTS` and
`CREATE OR REPLACE PROCEDURE`. The installing account therefore requires:

```sql
GRANT
  CREATE,
  CREATE ROUTINE,
  ALTER ROUTINE
ON `<database>`.*
TO '<owner>'@'<host>';
```

The definitions include primary keys, secondary indexes and checks inside
`CREATE TABLE`; they do not run a separate `ALTER TABLE` or `CREATE INDEX`.
Loading a definition does not run its procedure and does not change raw data.

MariaDB may automatically grant routine privileges to the creator depending on
`automatic_sp_privileges`. Explicit grants make the intended policy
independent of that setting.

### Running procedures

All procedures declare `SQL SECURITY INVOKER`. Database statements therefore
run with the privileges of the account executing `CALL`, not with hidden
privileges inherited from the routine definer.

The runner needs:

- `EXECUTE` on the installed routines;
- `SELECT` on source, mapping and managed tables read by those routines;
- `INSERT` and `DELETE` on managed output tables;
- `CREATE TEMPORARY TABLES` because tidy procedures use connection-local
  helper tables;
- object-specific `DROP` on `myair_tidy`, `smartwatchlow_tidy` and
  `smartwatchhigh_tidy` because their batched full-build error handlers use
  `TRUNCATE TABLE` to remove partial output.

The broad but understandable read and execution grants are:

```sql
GRANT EXECUTE, CREATE TEMPORARY TABLES
ON `<database>`.*
TO '<runner>'@'<host>';

GRANT SELECT
ON `<database>`.*
TO '<runner>'@'<host>';
```

`INSERT` and `DELETE` should be granted separately on each of the 17 managed
tables. For example:

```sql
GRANT SELECT, INSERT, DELETE
ON `<database>`.`gps_tidy`
TO '<runner>'@'<host>';
```

Repeat that object-specific grant for every managed table. Add the following
three narrowly scoped grants for full-build cleanup:

```sql
GRANT DROP ON `<database>`.`myair_tidy`
TO '<runner>'@'<host>';

GRANT DROP ON `<database>`.`smartwatchlow_tidy`
TO '<runner>'@'<host>';

GRANT DROP ON `<database>`.`smartwatchhigh_tidy`
TO '<runner>'@'<host>';
```

No implemented procedure requires direct `UPDATE`, `ALTER` or `INDEX` at
runtime.

## Refresh operations and transaction safety

The current pipeline does not use shadow tables or `RENAME TABLE`.

- GPS and Sleep tidy replacements use transactional `DELETE` plus `INSERT`.
- Large tidy full builds are committed one participant at a time to keep the
  InnoDB lock set bounded. Their handlers truncate partial output after an
  ordinary SQL error.
- Tidy incremental replacements use transactional delete and insert.
- Five-minute, hourly and daily tables use transactional full replacement.

For transactional replacements, a failed statement is rolled back and the
previous complete output remains visible. A terminated connection or server
failure during a batched tidy full build may prevent its error handler from
running; partial output must then be explicitly emptied before retrying.

`TRUNCATE TABLE` is treated by MariaDB as a drop-and-recreate operation and
causes an implicit commit. This is why the three batched procedures use it only
as full-build error cleanup and why it requires object-specific `DROP`.

## Recommended account separation

When possible, use two accounts:

### Definition owner

Installs and replaces the reviewed table and routine definitions. It has the
schema-level `CREATE`, `CREATE ROUTINE` and `ALTER ROUTINE` privileges and the
required access to existing managed objects.

### Nightly runner

Calls only approved procedures. It has `EXECUTE`, the read privileges needed
by the routines, managed-table `INSERT`/`DELETE`, temporary-table creation and
the three explicit cleanup grants described above. It does not need permission
to create or replace persistent schema objects.

One account may fulfil both roles, but the raw/managed boundary remains the
same.

## Privileges deliberately excluded

The ETL does not require global privileges such as:

```text
ALL PRIVILEGES
SUPER
FILE
PROCESS
SHUTDOWN
CREATE USER
GRANT OPTION
SET USER
```

Avoid schema-wide `DROP`, `ALTER`, `UPDATE` or other write privileges merely
for convenience. In particular, never grant object-specific write privileges
on raw or mapping tables.

## Verify the effective account and grants

Inside MariaDB, identify the authenticated identity and the account whose
privileges are effective:

```sql
SELECT
    CURRENT_USER() AS privilege_account,
    USER() AS connected_identity;

SHOW GRANTS FOR CURRENT_USER;
SELECT DATABASE() AS selected_database;
```

`CURRENT_USER()` is the account MariaDB used for privilege checking. `USER()`
shows the login identity supplied by the client and may differ because of host
matching or authentication configuration.

Inspect schema privileges:

```sql
SELECT
    GRANTEE,
    TABLE_SCHEMA,
    PRIVILEGE_TYPE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = '<database>'
ORDER BY GRANTEE, PRIVILEGE_TYPE;
```

Inspect table privileges:

```sql
SELECT
    GRANTEE,
    TABLE_SCHEMA,
    TABLE_NAME,
    PRIVILEGE_TYPE
FROM information_schema.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA = '<database>'
ORDER BY GRANTEE, TABLE_NAME, PRIVILEGE_TYPE;
```

Inspect routine privileges:

```sql
SELECT
    GRANTEE,
    ROUTINE_SCHEMA,
    ROUTINE_NAME,
    PRIVILEGE_TYPE
FROM information_schema.ROUTINE_PRIVILEGES
WHERE ROUTINE_SCHEMA = '<database>'
ORDER BY GRANTEE, ROUTINE_NAME, PRIVILEGE_TYPE;
```

## Pre-deployment checklist

- Confirm `SELECT DATABASE()` returns the intended target.
- Confirm `CURRENT_USER()` is the expected privilege account.
- Review `SHOW GRANTS FOR CURRENT_USER`.
- Verify that source and mapping tables have no ETL write grants.
- Verify that DDL and write privileges apply only to the named managed objects.
- Inspect each installed routine for `SQL SECURITY INVOKER`.
- Load definitions before granting access to the nightly runner.
- Validate primary-key uniqueness, coverage bounds and row summaries before
  scheduling the complete pipeline.

References: [MariaDB stored routine privileges](https://mariadb.com/docs/server/server-usage/stored-routines/stored-functions/stored-routine-privileges),
[MariaDB TRUNCATE TABLE](https://mariadb.com/docs/server/reference/sql-statements/table-statements/truncate-table).
