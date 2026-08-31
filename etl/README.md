# ETL workspace

This directory contains the rebuilt tidy and canonical five-minute components
currently under review.

The previous SQL procedures, orchestration scripts, cron example and diagnostic
extractor were removed so the ETL can be rebuilt and understood one component
at a time.

Current files:

```text
etl/
└── sql/
    ├── gps_tidy.sql
    ├── gps_5min.sql
    ├── myair_tidy.sql
    ├── myair_5min.sql
    ├── sleep_tidy.sql
    ├── smartwatchhigh_tidy.sql
    ├── smartwatchhigh_5min.sql
    ├── smartwatchlow_tidy.sql
    └── smartwatchlow_5min.sql
```

The SQL definitions have been compiled and exercised with temporary synthetic
MariaDB fixtures. No persistent test suite is stored in the repository while
the implementation is being reviewed piece by piece.

Each SQL file defines one output table and one parameterless procedure. Tidy
procedures automatically choose full or incremental refresh without a separate
state table. The initial five-minute procedures are deliberately full-only so
they remain correct when a tidy correction removes a previously materialized
minute.

- `gps_tidy.sql` has been validated against the representative database. Its
  specification is in
  [docs/gps-tidy-specification.md](../docs/gps-tidy-specification.md).
- `myair_tidy.sql` has completed full and incremental operational validation.
  Its specification is in
  [docs/myair-tidy-specification.md](../docs/myair-tidy-specification.md).
- `smartwatchlow_tidy.sql`, `smartwatchhigh_tidy.sql` and `sleep_tidy.sql` have
  passed local synthetic validation but retain the primary-database validation
  tasks listed in their specifications.
- The four `*_5min.sql` definitions share the participant/UTC-bucket grain and
  are documented in their corresponding `docs/*-5min-specification.md` files.

No deployment script or scheduler is included yet. Database execution remains
manual and requires an explicit target confirmation. Five-minute operational
validation should proceed one stream at a time, starting with GPS.
