# ETL execution

```text
sql/             table and stored-procedure definitions
run_etl.sh       dependency-ordered nightly runner
crontab.example  cron example
```

Each SQL file creates its managed table when absent and replaces one
parameterless procedure. Loading a definition does not execute it or modify raw
tables.

Tidy procedures run a full build when their table is empty and an incremental
refresh otherwise. Five-minute, hourly and daily procedures use transactional
full replacement. Sleep ends at its nightly tidy layer.

Shared behaviour is documented in
[`docs/architecture.md`](../docs/architecture.md).

## Run

```bash
ETL_DATABASE=<database> ./etl/run_etl.sh
```

The database can alternatively be the first argument. To select another local
MariaDB client configuration:

```bash
ETL_DATABASE=<database> \
ETL_DEFAULTS_FILE=/absolute/path/to/client.cnf \
./etl/run_etl.sh
```

The runner calls all 17 procedures in dependency order, stops on the first
error and uses `flock` to prevent overlapping runs.

## Cron

Replace the placeholders in [`crontab.example`](crontab.example), then copy its
active lines into:

```bash
crontab -e
```

Cron uses the server timezone. Credentials must be available through the
MariaDB client configuration.

Installation commands are in
[`docs/install-etl.md`](../docs/install-etl.md); required privileges are in
[`docs/database-permissions.md`](../docs/database-permissions.md).
