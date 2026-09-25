# TRIGGER ETL

MariaDB 10.11 ETL for participant-level TRIGGER sensor data.

```text
GPS / MyAir / SmartwatchLow / SmartwatchHigh
raw → tidy minutes → 5-minute buckets → hours → days

Sleep: raw → tidy participant-nights
```

Raw data remains read only. Tidy resolves duplicates and cleans measurements;
aggregates summarize observed time units. All sensor time boundaries use UTC.
Study windows, coverage thresholds and derived model variables belong in analyses.

## Documentation

| Document | Contents |
|---|---|
| [Architecture](docs/architecture.md) | Keys, refresh strategy and operational limits |
| [Tidy cleaning](docs/tidy-cleaning.md) | Shared exclusions, measurement rules and units |
| [Aggregations](docs/aggregations.md) | Weighting, coverage and provenance |
| [Install and run](docs/install-etl.md) | Installation, execution and scheduling |
| [Database permissions](docs/database-permissions.md) | Accounts, privileges and source protection |

## Run

After [installing the definitions](docs/install-etl.md):

```bash
ETL_DATABASE=your_database ./etl/run_etl.sh
```

Credentials come from local MariaDB client configuration. The runner executes
all 17 procedures in dependency order and stops on error.
Definitions are in [`etl/sql/`](etl/sql/); the schedule example is
[`etl/crontab.example`](etl/crontab.example).
