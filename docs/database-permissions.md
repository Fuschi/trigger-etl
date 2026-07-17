# Database permissions and safety model

## Objective

The ETL account must be able to:

- read raw TRIGGER tables;
- create and execute ETL routines;
- create views;
- rebuild only managed derived tables;
- operate freely in the development database.

It must not have schema-wide privileges that allow raw tables in `triggerIO` to be updated, deleted, altered or dropped.

## Database roles

| Database | Intended access |
|---|---|
| `triggerIO-dev` | development and testing; broad write and DDL access |
| `triggerIO` | read-only access to raw data; write and DDL access restricted to ETL-managed objects |

## Main database privileges

The following schema-level privileges support reading data and defining ETL objects without granting schema-wide data modification:

```sql
GRANT
  SELECT,
  CREATE,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW,
  SHOW VIEW,
  CREATE ROUTINE,
  ALTER ROUTINE
ON `triggerIO`.*
TO '<etl_user>'@'<host>';
```

Do **not** grant the following privileges on `triggerIO` as a whole:

```text
INSERT
UPDATE
DELETE
DROP
ALTER
INDEX
```

Those privileges must be restricted to ETL-managed tables.

## ETL-managed tables

The current derived tables are:

```text
myair_tidy
smartwatchhigh_tidy
smartwatchlow_tidy
gps_tidy
sleep_tidy

myair_5min
smartwatchhigh_5min
smartwatchlow_5min
gps_5min

myair_hourly
smartwatchhigh_hourly
smartwatchlow_hourly
gps_hourly

myair_daily
smartwatchhigh_daily
smartwatchlow_daily
gps_daily
```

Each managed table requires object-specific privileges. The current procedures perform full rebuilds, so `DROP`, `CREATE` and `INSERT` are essential. `ALTER` and `INDEX` are retained for controlled schema maintenance.

Example:

```sql
GRANT
  SELECT,
  INSERT,
  UPDATE,
  DELETE,
  DROP,
  ALTER,
  INDEX
ON `triggerIO`.`myair_tidy`
TO '<etl_user>'@'<host>';
```

Apply the same grant only to each table listed above.

Schema-level `CREATE` is required because procedures recreate tables after dropping them. Table-specific grants remain associated with the table name and continue to apply when the table is recreated.

## Raw-table protection

Raw tables are protected because the ETL account has only `SELECT` at schema level and receives write or DDL privileges only on explicitly listed derived tables.

The account must not receive schema-wide `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE` or `INDEX` privileges on `triggerIO`.

> A schema-wide `INDEX` grant still allows indexes on raw tables to be created or removed. For a strict safety model, grant `INDEX` only on ETL-managed tables.

## Views

Creating a new view requires `CREATE VIEW`. Inspecting it requires `SHOW VIEW`.

`CREATE OR REPLACE VIEW` may also require permission to replace the existing view. For `active_accounts`, either grant `DROP` only on that view:

```sql
GRANT DROP
ON `triggerIO`.`active_accounts`
TO '<etl_user>'@'<host>';
```

or use `CREATE VIEW IF NOT EXISTS`. The latter is safer but does not update an existing view definition.

## Development database

The development database can use broader privileges because it is the validation environment:

```sql
GRANT ALL PRIVILEGES
ON `triggerIO-dev`.*
TO '<etl_user>'@'<host>';
```

Production SQL changes should be deployed and tested on `triggerIO-dev` before being applied to `triggerIO`.

## Verification

Inspect the effective grants for the connected account:

```sql
SHOW GRANTS FOR CURRENT_USER;
```

Inspect privileges granted on the main schema:

```sql
SELECT
  GRANTEE,
  TABLE_SCHEMA,
  TABLE_NAME,
  PRIVILEGE_TYPE
FROM information_schema.TABLE_PRIVILEGES
WHERE TABLE_SCHEMA = 'triggerIO'
ORDER BY TABLE_NAME, PRIVILEGE_TYPE;
```

Review schema-level privileges:

```sql
SELECT
  GRANTEE,
  TABLE_SCHEMA,
  PRIVILEGE_TYPE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA IN ('triggerIO', 'triggerIO-dev')
ORDER BY TABLE_SCHEMA, PRIVILEGE_TYPE;
```

## Safety rule

Any new ETL materialized table must be added explicitly to the managed-table privilege list. Raw tables must never be added to that list.
