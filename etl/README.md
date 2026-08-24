# ETL workspace

This directory contains only the first rebuilt ETL component.

The previous SQL procedures, orchestration scripts, cron example and diagnostic
extractor were removed so the ETL can be rebuilt and understood one component
at a time.

Current files:

```text
etl/
└── sql/
    └── gps_tidy.sql
```

Synthetic tests are intentionally deferred while the SQL implementation is
being simplified and reviewed piece by piece.

`gps_tidy.sql` defines one output table and one parameterless procedure. The
procedure performs a full refresh when the table is empty and an incremental
refresh otherwise, without a separate state table. Its data specification is
in [docs/gps-tidy-specification.md](../docs/gps-tidy-specification.md).

No deployment script or scheduler is included yet. Database execution remains
manual and requires an explicit target confirmation. Do not add the next layer
until the GPS tidy specification has been verified against representative source
metadata and aggregate diagnostics.
