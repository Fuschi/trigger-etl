# TRIGGER ETL

MariaDB ETL pipeline for cleaning, deduplicating and temporally aggregating environmental, wearable, GPS and sleep data collected within the TRIGGER project.

## Architecture

```text
raw → tidy → 5-minute → hourly → daily
```

Sleep data are natively daily/nightly and follow a separate path:

```text
sleep → sleep_tidy
```

The pipeline is implemented through version-controlled SQL procedures and Bash scripts for deployment, execution, logging and scheduled runs.

## Data streams

| Stream | Measurements | Derived layers |
|---|---|---|
| `myair` | particulate matter, particle counts, temperature, humidity, pressure, sound, UVB and light | tidy, 5-minute, hourly, daily |
| `smartwatchhigh` | heart rate, oxygen saturation, respiratory rate and sleep stage | tidy, 5-minute, hourly, daily |
| `smartwatchlow` | steps, calories, blood pressure and temperature | tidy, 5-minute, hourly, daily |
| `gps` | longitude, latitude and accuracy | tidy, 5-minute, hourly, daily |
| `sleep` | nightly sleep summaries | tidy |

## Processing principles

- deterministic deduplication at reading and minute level;
- retention of devices mapped to exactly one user;
- stream-specific validity checks;
- equal temporal weighting of 5-minute buckets in hourly means;
- equal weighting of hourly means in daily means;
- explicit coverage metadata at every aggregation level;
- fixed 24-element JSON profiles in daily tables, reporting the number of valid 5-minute buckets in each hour;
- no modification of raw source tables.

No minimum coverage threshold is enforced by the ETL. Coverage fields are retained so analytical workflows can apply appropriate quality criteria downstream.

## Repository structure

```text
.
├── README.md
├── LICENSE
├── docs
│   └── database-permissions.md
└── etl
    ├── bin          # deployment and execution scripts
    ├── sql          # views, schemas and ETL procedures
    ├── diagnosis    # read-only diagnostic exports
    └── cron         # scheduling example
```

## Requirements

- MariaDB 10.11 or a compatible version;
- MariaDB/MySQL command-line client;
- Bash;
- `flock`, normally provided by the Linux `util-linux` package;
- non-interactive database authentication for scheduled execution.

`flock` prevents overlapping pipeline runs. `run_etl.sh` acquires a non-blocking lock on `logs/run_etl.lock`; if another ETL process already holds the lock, the new execution exits without starting a second pipeline.

## Usage

Deploy SQL definitions and procedures:

```bash
./etl/bin/deploy_sql.sh
```

Run the development pipeline:

```bash
./etl/bin/run_etl.sh --env dev
```

Run the main pipeline:

```bash
./etl/bin/run_etl.sh --env main
```

Deployment and execution logs are written to `logs/`.

The deployment script targets `triggerIO-dev` before `triggerIO`. SQL changes should always be validated on development before execution against the main database.

## Documentation

- [SQL conventions and aggregation semantics](etl/sql/README.md)
- [Database permissions and safety model](docs/database-permissions.md)

## License

Distributed under the [MIT License](LICENSE).
