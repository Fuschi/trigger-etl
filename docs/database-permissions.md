# Database permissions and safety model

## Purpose

This document records the privileges needed by the account used to inspect,
build and run the TRIGGER ETL.

Database names and internal environment topology intentionally remain outside
the repository. Replace the placeholders below using local operational
configuration:

```text
<database>       target TRIGGER database
<etl_user>       ETL account name
<host>           allowed client host
<managed_table>  table created and owned by the ETL
<managed_view>   view created and owned by the ETL
<procedure>      stored procedure created and owned by the ETL
```

The primary safety boundary is simple:

- raw source tables are read-only;
- only explicitly managed ETL objects may be changed;
- database-wide destructive or write privileges should be avoided;
- effective grants must be inspected before the first database-changing step.

## Read-only inspection

Designing tidy rules requires inspecting schemas, value distributions, key
cardinalities and edge cases in the representative database.

The minimum data privilege is:

```sql
GRANT SELECT
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Schema-wide `SELECT` allows the account to inspect raw tables but does not allow
their contents or definitions to be changed.

If view definitions must be inspected, also grant:

```sql
GRANT SHOW VIEW
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Metadata in `information_schema` is normally visible according to the
account's privileges. No global administrative privilege is required for the
planned ETL work.

## Creating stored procedures

The account that creates stored procedures requires:

```sql
GRANT
  CREATE ROUTINE,
  ALTER ROUTINE
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

`CREATE ROUTINE` permits procedure creation. `ALTER ROUTINE` permits changing
or dropping routines. MariaDB normally grants `ALTER ROUTINE` and `EXECUTE`
automatically to a routine creator, but explicit grants make the intended
operational permission model visible and do not depend on the
`automatic_sp_privileges` server setting.

If the same account calls the procedures, grant:

```sql
GRANT EXECUTE
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Avoid declaring a different `DEFINER` unless the account and privilege model
have been deliberately designed. Procedures should state `SQL SECURITY`
explicitly so execution does not depend on an unnoticed default.

Official reference: [MariaDB stored routine privileges](https://mariadb.com/docs/server/server-usage/stored-routines/stored-functions/stored-routine-privileges).

## Creating managed tables

Creating a new table requires schema-level `CREATE`:

```sql
GRANT CREATE
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Temporary tables, when used for intermediate calculations, require:

```sql
GRANT CREATE TEMPORARY TABLES
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Do not grant schema-wide `INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER` or
`INDEX`. Grant them only on ETL-managed objects:

```sql
GRANT
  SELECT,
  INSERT,
  UPDATE,
  DELETE,
  DROP,
  ALTER,
  INDEX
ON `<database>`.`<managed_table>`
TO '<etl_user>'@'<host>';
```

The exact set can be reduced after the implementation is known. For example,
an append-free full materialization may not need `UPDATE` or `DELETE`.

Raw tables must never receive object-specific write or DDL grants.

## Shadow tables and atomic replacement

The rebuilt ETL should populate a shadow table, validate it and swap it into
place instead of dropping the current valid table before a long insert.

MariaDB requires `DROP`, `CREATE` and `INSERT` privileges for every table
participating in `RENAME TABLE`. These privileges must therefore cover the
fixed managed names used in the swap, for example:

```text
<managed_table>
<managed_table>__next
<managed_table>__previous
```

Do not use unpredictable shadow-table names if the account relies on narrowly
scoped object grants.

An atomic swap can use:

```sql
RENAME TABLE
  `<managed_table>` TO `<managed_table>__previous`,
  `<managed_table>__next` TO `<managed_table>`;
```

Grant all required permissions on the fixed managed names before enabling the
swap. `RENAME TABLE` does not transfer grants from one table name to another;
permissions must be designed around the names used operationally.

Official reference: [MariaDB RENAME TABLE](https://mariadb.com/docs/server/reference/sql-statements/data-definition/rename-table).

## Views

Creating a new view requires `CREATE VIEW` plus `SELECT` on the referenced
columns:

```sql
GRANT
  CREATE VIEW,
  SHOW VIEW
ON `<database>`.*
TO '<etl_user>'@'<host>';
```

Replacing an existing view with `CREATE OR REPLACE VIEW` additionally requires
`DROP` on that view. Because schema-wide `DROP` would also permit dropping raw
tables, it must not be granted merely to manage views.

Instead, choose one of these approaches:

1. grant `DROP` only on the specific managed view;
2. have an authorized owner replace the view;
3. create a versioned new view and switch consumers separately.

Views exposing participant data should select only the columns required by
analyses. Do not expose email or other identifying attributes when a
pseudonymous participant key is sufficient.

Official reference: [MariaDB CREATE VIEW](https://mariadb.com/docs/server/server-usage/views/create-view).

## Recommended account separation

When practical, use two roles or accounts:

### Object owner or deployment account

May create and replace explicitly managed tables, views and routines. It has
the narrowly scoped DDL privileges described above.

### Runtime account

Needs only:

- `EXECUTE` on approved procedures;
- `SELECT` on outputs needed for validation;
- no direct DDL privilege;
- no direct raw-table write privilege.

This separation prevents an execution script from modifying arbitrary schema
objects even if its credentials are misused.

During the early step-by-step rebuild, one account may temporarily perform both
roles. If so, its effective grants must still follow the raw/managed boundary.

## Privileges that should not be granted globally

The ETL account does not need:

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

It should not receive database-wide write or destructive privileges unless a
specific implementation makes that unavoidable and the exception is reviewed.

## Verification queries

Inspect the current account:

```sql
SELECT CURRENT_USER(), USER();
SHOW GRANTS FOR CURRENT_USER;
```

Inspect schema-level privileges:

```sql
SELECT
  GRANTEE,
  TABLE_SCHEMA,
  PRIVILEGE_TYPE
FROM information_schema.SCHEMA_PRIVILEGES
WHERE TABLE_SCHEMA = '<database>'
ORDER BY GRANTEE, PRIVILEGE_TYPE;
```

Inspect table and view privileges:

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

## Checklist before changing the database

- Confirm the exact database selected by the connection.
- Run `SHOW GRANTS FOR CURRENT_USER`.
- Confirm raw tables have no write or DDL grants.
- List the exact managed objects that may change.
- Confirm whether the action is read-only, creates a new object or replaces an
  existing object.
- Confirm the privileges needed for every shadow-table name.
- Confirm procedure `DEFINER` and `SQL SECURITY` behaviour.
- Require explicit confirmation before executing DDL.
- Validate output keys and row counts before an atomic swap.
- Record any privilege change outside credentials and secrets.

## Objects used by the rebuilt tidy components

The implemented tidy definitions narrow the generic placeholders above to
these managed objects:

```text
gps_tidy
etl_gps_tidy
myair_tidy
etl_myair_tidy
smartwatchlow_tidy
etl_smartwatchlow_tidy
smartwatchhigh_tidy
etl_smartwatchhigh_tidy
```

Their source boundaries are read-only `SELECT` on `gps`, `user_gps`, `myair`
and `user_myair`, plus `smartwatchlow`, `user_smartwatchlow`, `smartwatchhigh`
and `user_smartwatchhigh`. Execution requires `SELECT`, `INSERT` and `DELETE`
on the corresponding managed tidy table. The MyAir, SmartwatchLow and
SmartwatchHigh full-build error handlers also use `TRUNCATE TABLE` on their
managed tidy table to remove participant batches committed before a later
batch failed, so the caller additionally needs object-specific `DROP` on
`myair_tidy`, `smartwatchlow_tidy` and `smartwatchhigh_tidy`. The procedures
create connection-local temporary helper tables, so the invoking privilege
model must also account for `CREATE TEMPORARY TABLES`.

The procedures use `SQL SECURITY INVOKER`: the calling account, rather than an
implicit privileged definer, must possess the required runtime privileges.
Before granting any permission, compare the exact operations in the relevant
file under `etl/sql/` with the chosen owner/runtime account separation.
