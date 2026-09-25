# Database permissions

Use local configuration for database, host and account names; never commit
credentials. Confirm the exact target before installing definitions or
replacing managed data.

## Object boundary

| Objects | Access |
|---|---|
| `gps`, `myair`, `smartwatchlow`, `smartwatchhigh`, `sleep` | Read only |
| Corresponding `user_<stream>` mappings | Read only |
| Each sensor's `_tidy`, `_5min`, `_hourly`, `_daily`; `sleep_tidy` | 17 managed output tables |
| `etl_<output_table>()` | 17 managed procedures |

All procedures use `SQL SECURITY INVOKER`: the caller's privileges apply.
Use separate installer and runner accounts where practical.

## Required privileges

| Account / activity | Privileges | Scope |
|---|---|---|
| Inspection | `SELECT` | Source, mapping and managed tables |
| Installer | `CREATE`, `CREATE ROUTINE`, `ALTER ROUTINE` | Target schema |
| Runner | `EXECUTE` | Installed ETL procedures |
| Runner | `SELECT` | Source, mapping and managed tables |
| Runner | `INSERT`, `DELETE` | Each managed output table |
| Runner | `CREATE TEMPORARY TABLES` | Target schema |
| Runner | `DROP` | Only `myair_tidy`, `smartwatchlow_tidy`, `smartwatchhigh_tidy` |

The three `DROP` grants support `TRUNCATE` cleanup after batched full-build
errors. No source writes, schema-wide `DROP`, or global administrative grants
are required. Runtime does not require `UPDATE`, `ALTER` or `INDEX`.

Example grants; replace placeholders and repeat managed-table/routine grants
for all 17 outputs:

```sql
GRANT CREATE, CREATE ROUTINE, ALTER ROUTINE
ON `<database>`.* TO '<owner>'@'<host>';

GRANT SELECT, CREATE TEMPORARY TABLES
ON `<database>`.* TO '<runner>'@'<host>';

GRANT EXECUTE ON PROCEDURE `<database>`.`etl_gps_tidy`
TO '<runner>'@'<host>';
GRANT INSERT, DELETE ON `<database>`.`gps_tidy`
TO '<runner>'@'<host>';

GRANT DROP ON `<database>`.`myair_tidy` TO '<runner>'@'<host>';
GRANT DROP ON `<database>`.`smartwatchlow_tidy` TO '<runner>'@'<host>';
GRANT DROP ON `<database>`.`smartwatchhigh_tidy` TO '<runner>'@'<host>';
```

The schema-wide `SELECT` above is a convenient read grant; it can instead be
restricted to the listed tables. Create routines before granting their execution.
An installer that also runs procedures needs the runner privileges too.

## Verify before deployment

```sql
SELECT DATABASE() AS target_database,
       CURRENT_USER() AS privilege_account,
       USER() AS connected_identity;
SHOW GRANTS FOR CURRENT_USER;
```

Verify target and account, read-only source access, and writes restricted to
managed outputs. Loading definitions does not execute procedures or migrate
existing tables. See [installation](install-etl.md) and
[transaction/recovery behavior](architecture.md#transactions-and-diagnostics).
