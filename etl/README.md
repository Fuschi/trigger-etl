# ETL files

| Path | Purpose |
|---|---|
| [`sql/`](sql/) | One table and parameterless procedure per SQL file |
| [`run_etl.sh`](run_etl.sh) | Executes the 17 procedures in dependency order |
| [`crontab.example`](crontab.example) | Nightly schedule template |

See [install and run](../docs/install-etl.md) for commands and configuration,
and the [main README](../README.md) for data documentation.
