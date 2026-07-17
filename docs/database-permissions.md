# Database permissions and safety model

## Scope

The ETL account must be able to:

* read raw TRIGGER tables;
* create and execute ETL routines;
* rebuild ETL-managed derived tables;
* create new views;
* operate freely in `triggerIO-dev`.

It must not have schema-wide privileges that allow raw production tables to be modified, altered or dropped.

## Database access

| Database        | Access model                                                                     |
| --------------- | -------------------------------------------------------------------------------- |
| `triggerIO-dev` | broad write and DDL access for development and testing                           |
| `triggerIO`     | read-only access to raw tables; write and DDL access only on managed ETL objects |

## Production schema privileges

Recommended schema-level privileges:

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

Do not grant schema-wide:

```text
INSERT
UPDATE
DELETE
DROP
ALTER
INDEX
```

These privileges must be restricted to explicitly managed ETL tables.

## ETL-managed tables

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

Each managed table requires object-specific privileges:

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

Apply the same grant only to the managed tables listed above.

Schema-level `CREATE` is still required because ETL procedures recreate tables after dropping them.

## Raw-table protection

Raw tables receive only schema-level `SELECT`.

They must never receive object-specific:

```text
INSERT
UPDATE
DELETE
DROP
ALTER
INDEX
```

privileges.

## Views

The ETL account can create and inspect views through:

```sql
GRANT
  CREATE VIEW,
  SHOW VIEW
ON `triggerIO`.*
TO '<etl_user>'@'<host>';
```

It must not receive schema-wide `DROP`, because MariaDB does not distinguish between dropping views and dropping tables at that privilege level.

Therefore:

* new views can be created by the ETL account;
* existing production views must be replaced or removed by the database administrator or an authorized deployment account;
* view changes must first be tested in `triggerIO-dev`.

Example managed view:

```sql
CREATE OR REPLACE VIEW active_accounts AS
SELECT
  id AS userId,
  UPPER(LEFT(email, 2)) AS nationality,
  email,
  last_login
FROM accounts
WHERE last_login IS NOT NULL
  AND UPPER(LEFT(email, 2)) IN ('CH', 'DE', 'GR', 'IT');
```

## Development database

The development database can use broader privileges:

```sql
GRANT ALL PRIVILEGES
ON `triggerIO-dev`.*
TO '<etl_user>'@'<host>';
```

All ETL schema changes should be tested there before production deployment.

## Verification

Inspect effective grants:

```sql
SHOW GRANTS FOR CURRENT_USER;
```

Inspect object-specific privileges:

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

Inspect schema-level privileges:

```sql
SELECT
  GRANTEE,
  TABLE_SCHEMA,
  PRIVILEGE_TYPE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA IN ('triggerIO', 'triggerIO-dev')
ORDER BY TABLE_SCHEMA, PRIVILEGE_TYPE;
```

## Safety rules

* Grant write and DDL privileges only on managed ETL tables.
* Never grant schema-wide `DROP`, `ALTER`, `INSERT`, `UPDATE`, `DELETE` or `INDEX` on `triggerIO`.
* Test all schema changes in `triggerIO-dev`.
* Deploy changes to existing production views through the database administrator.

