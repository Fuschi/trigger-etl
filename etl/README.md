# ETL workspace

This directory contains the rebuilt tidy components currently under review.

The previous SQL procedures, orchestration scripts, cron example and diagnostic
extractor were removed so the ETL can be rebuilt and understood one component
at a time.

Current files:

```text
etl/
└── sql/
    ├── gps_tidy.sql
    └── myair_tidy.sql
```

Synthetic tests are intentionally deferred while the SQL implementation is
being simplified and reviewed piece by piece.

Each SQL file defines one output table and one parameterless procedure. A
procedure performs a full refresh when its tidy table is empty and an
incremental refresh otherwise, without a separate state table.

- `gps_tidy.sql` has been validated against the representative database. Its
  specification is in
  [docs/gps-tidy-specification.md](../docs/gps-tidy-specification.md).
- `myair_tidy.sql` is implemented for review but still requires source-schema
  and aggregate data validation. Its specification is in
  [docs/myair-tidy-specification.md](../docs/myair-tidy-specification.md).

No deployment script or scheduler is included yet. Database execution remains
manual and requires an explicit target confirmation. Do not add the MyAir
five-minute layer until the tidy definition has been verified against
representative source metadata and aggregate diagnostics.
