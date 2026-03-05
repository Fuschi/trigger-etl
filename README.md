# TRIGGER ETL

ETL pipeline for building **clean hourly and daily aggregates** from raw
IoT device data stored in MariaDB.

The project provides:

-   reproducible SQL deployment
-   deterministic ETL rebuilds
-   analytical stored procedures
-   logging and error handling
-   safe execution in production environments

The pipeline processes data from multiple device types including:

-   GPS
-   MyAir environmental sensors
-   Smartwatch high-frequency sensors
-   Smartwatch low-frequency sensors
-   Sleep data

------------------------------------------------------------------------

## Architecture

The ETL pipeline transforms raw device measurements into cleaned hourly datasets and analytical daily summaries.

The data flow follows a simple three-stage structure:

```
Raw Tables
   │  deduplication
   │  validation
   │  aggregation
   ▼
Hourly Tables
   │
   │  aggregation
   │  data-quality filtering
   ▼
Daily Procedures
```

### Raw tables

Raw tables contain the original device measurements collected from IoT devices.

Examples:

- `gps`
- `myair`
- `smartwatchhigh`
- `smartwatchlow`
- `sleep`

These tables may contain:

- duplicate measurements
- ambiguous timestamps
- multiple users associated with the same device

No cleaning is performed at this stage.

---

### Hourly tables

Hourly tables are built by the ETL scripts and represent the first cleaned dataset.

Examples:

- `gps_hourly`
- `myair_hourly`
- `smartwatchhigh_hourly`
- `smartwatchlow_hourly`

During the ETL rebuild the pipeline performs:

- strict timestamp deduplication
- validation of device → user mappings
- hourly aggregation of sensor measurements

Each hourly table is keyed by:

```
userId
deviceId
firmware
date
hour
```

and contains statistical aggregates such as:

- mean
- min
- max
- valid_n (number of valid measurements)
- records_n (total records contributing)

---

### Daily analytical procedures

Daily summaries are generated **on demand** through stored procedures.

Examples:

- `sp_gps_daily`
- `sp_myair_daily`
- `sp_smartwatchhigh_daily`
- `sp_smartwatchlow_daily`
- `sp_sleep_tidy`
- `sp_active_accounts`

These procedures:

- aggregate hourly data at the daily level
- apply configurable data-quality thresholds
- return result sets without creating persistent tables

This design keeps the database lightweight while allowing flexible analytical queries.


------------------------------------------------------------------------

# SQL Deployment

All SQL objects are deployed through:

etl/bin/deploy_sql.sh

The script:

-   deploys SQL files in deterministic order
-   logs execution results
-   stops immediately on errors

Example:

./etl/bin/deploy_sql.sh

The script deploys to multiple databases:

triggerIO-dev\
triggerIO

Deployment logs are stored in:

logs/deploy_sql_YYYYMMDD_HHMMSS.log

------------------------------------------------------------------------

# ETL Execution

Hourly tables are rebuilt using:

etl/bin/run_etl.sh

The script executes stored procedures such as:

rebuild_myair_hourly\
rebuild_smartwatchhigh_hourly\
rebuild_smartwatchlow_hourly\
rebuild_gps_hourly

Each rebuild performs:

-   strict deduplication
-   safe table rebuild 
-   deterministic aggregation

Logs are stored in:

logs/run_etl_YYYYMMDD.log

------------------------------------------------------------------------

# Stored Procedures

Daily analytics are computed using stored procedures.

Example:

CALL sp_gps_daily( 5, '2026-03-01', '2026-03-05', NULL, NULL, NULL,
NULL, NULL );

------------------------------------------------------------------------

# Optional Filtering

Procedures allow optional filters using NULL parameters.

Example:

CALL sp_sleep_tidy(NULL, NULL, 123, NULL, NULL);

Internally this translates to:

WHERE (p_userId IS NULL OR userId = p_userId)

------------------------------------------------------------------------

# Logging

Both scripts produce structured logs.

Example:

[2026-03-05 10:10:03] SQL deploy started\
[2026-03-05 10:10:03] Deploying to: triggerIO\
[2026-03-05 10:10:03] Applying: etl_myair_hourly.sql\
[2026-03-05 10:10:03] OK

Logs capture:

-   timestamps
-   executed files
-   warnings
-   SQL errors

------------------------------------------------------------------------

## Database Permissions

The ETL user (`alessandro.fuschi2`) is configured with restricted privileges to **protect raw ingestion tables** while allowing full control on **hourly ETL tables** rebuilt by the pipeline.

Raw tables are **read-only** for the ETL user, preventing accidental modifications to original device data.

Protected raw tables:

- `gps`
- `myair`
- `smartwatchhigh`
- `smartwatchlow`
- `sleep`
- `accounts`
- `user_sleep`

Hourly ETL tables are fully managed by the pipeline and therefore allow full DML and schema operations:

- `gps_hourly`
- `myair_hourly`
- `smartwatchhigh_hourly`
- `smartwatchlow_hourly`

---

### Grant configuration

```sql
-- Optionally, reset user privileges
REVOKE ALL PRIVILEGES, GRANT OPTION
ON triggerIO.*
FROM 'alessandro.fuschi2'@'localhost';

-- Global privilege
GRANT EXECUTE
ON *.*
TO 'alessandro.fuschi2'@'localhost'
IDENTIFIED VIA unix_socket;

-- Production database (restricted privileges)
GRANT
  SELECT,
  CREATE,
  INDEX,
  CREATE TEMPORARY TABLES,
  EXECUTE,
  CREATE VIEW,
  SHOW VIEW,
  CREATE ROUTINE,
  ALTER ROUTINE
ON triggerIO.*
TO 'alessandro.fuschi2'@'localhost';

-- Development database (full privileges for testing)
GRANT
  SELECT, INSERT, UPDATE, DELETE,
  CREATE, DROP, INDEX, ALTER,
  CREATE TEMPORARY TABLES, LOCK TABLES,
  EXECUTE, CREATE VIEW, SHOW VIEW,
  CREATE ROUTINE, ALTER ROUTINE
ON `triggerIO-dev`.*
TO 'alessandro.fuschi2'@'localhost';

-- Hourly ETL tables in production (full control required for rebuilds)
GRANT SELECT, INSERT, UPDATE, DELETE, DROP, INDEX, ALTER
ON triggerIO.myair_hourly
TO 'alessandro.fuschi2'@'localhost';

GRANT SELECT, INSERT, UPDATE, DELETE, DROP, INDEX, ALTER
ON triggerIO.gps_hourly
TO 'alessandro.fuschi2'@'localhost';

GRANT SELECT, INSERT, UPDATE, DELETE, DROP, INDEX, ALTER
ON triggerIO.smartwatchhigh_hourly
TO 'alessandro.fuschi2'@'localhost';

GRANT SELECT, INSERT, UPDATE, DELETE, DROP, INDEX, ALTER
ON triggerIO.smartwatchlow_hourly
TO 'alessandro.fuschi2'@'localhost';
```

------------------------------------------------------------------------


# Example Queries

Active accounts:

CALL sp_active_accounts();

Daily GPS aggregation:

CALL sp_gps_daily( 5, '2026-03-01', '2026-03-07', NULL, NULL, NULL,
NULL, NULL );

Sleep dataset cleanup:

CALL sp_sleep_tidy(NULL, NULL, NULL, NULL, NULL);
