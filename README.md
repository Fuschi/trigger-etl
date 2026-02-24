# TRIGGER ETL

Simple ETL pipeline to rebuild hourly and daily aggregated tables from
raw sensor data.

------------------------------------------------------------------------

## Database

All stored procedures and tables are created in the triggerIO database. The ETL scripts connect to MySQL using the local socket.

------------------------------------------------------------------------

## Deploy SQL

To deploy or update stored procedures:

    ./etl/bin/deploy_sql.sh

------------------------------------------------------------------------

## Run ETL

To execute all aggregation procedures:

    ./etl/bin/run_etl.sh

The script:

-   Calls each stored procedure
-   Logs execution time
-   Logs final row count
-   Prevents concurrent runs
-   Writes logs to `logs/`

------------------------------------------------------------------------

## Aggregations

-   Hourly tables compute mean/min/max and valid measurement counts.
-   Daily tables are built from hourly tables.

To modify the execution order, edit the **ETL STEPS** section in:

    etl/bin/run_etl.sh