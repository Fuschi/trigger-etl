# TRIGGER ETL

MariaDB transformations from immutable raw sensor uploads to participant-level
tables for analysis:

```text
raw → tidy participant-minutes → 5-minute buckets → hours → days
```

Sleep ends at `sleep_tidy` because its source is already nightly.

## Main decisions

- Raw and mapping tables are read only.
- Tidy removes unresolved duplicates, ambiguous participant mappings and
  technically unusable data according to each stream specification.
- Five minutes are the common interval used across sensor streams.
- A bucket based on one minute and a bucket based on five minutes have equal
  weight in hourly and daily means; coverage counts preserve the difference.
- All time buckets use UTC.
- Study windows, coverage thresholds and derived analysis variables remain
  outside the core ETL.

See [docs/architecture.md](docs/architecture.md) for the complete shared policy.

## Implemented tables

| Stream | Tidy | Five-minute | Hourly | Daily |
|---|---|---|---|---|
| GPS | [spec](docs/gps-tidy-specification.md) | [spec](docs/gps-5min-specification.md) | [spec](docs/gps-hourly-specification.md) | [spec](docs/gps-daily-specification.md) |
| MyAir | [spec](docs/myair-tidy-specification.md) | [spec](docs/myair-5min-specification.md) | [spec](docs/myair-hourly-specification.md) | [spec](docs/myair-daily-specification.md) |
| SmartwatchLow | [spec](docs/smartwatchlow-tidy-specification.md) | [spec](docs/smartwatchlow-5min-specification.md) | [spec](docs/smartwatchlow-hourly-specification.md) | [spec](docs/smartwatchlow-daily-specification.md) |
| SmartwatchHigh | [spec](docs/smartwatchhigh-tidy-specification.md) | [spec](docs/smartwatchhigh-5min-specification.md) | [spec](docs/smartwatchhigh-hourly-specification.md) | [spec](docs/smartwatchhigh-daily-specification.md) |
| Sleep | [spec](docs/sleep-tidy-specification.md) | — | — | — |

Primary keys are `(userId, minute_ts)` for tidy sensor data,
`(userId, bucket_5min)` for five-minute data, `(userId, hour_ts)` for hourly
data and `(userId, date)` for daily and Sleep data.

## Repository

```text
etl/sql/            table and procedure definitions
etl/run_etl.sh      nightly runner
etl/crontab.example cron example
docs/               architecture, specifications and operations
```

Install definitions with [docs/install-etl.md](docs/install-etl.md), then run:

```bash
ETL_DATABASE=<database> ./etl/run_etl.sh
```

The runner executes all procedures in dependency order, stops on error and
prevents overlapping runs. Credentials are read from the MariaDB client
configuration.

Required privileges are documented in
[docs/database-permissions.md](docs/database-permissions.md).
