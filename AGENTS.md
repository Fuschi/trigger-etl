# Project instructions

- Keep it simple: explicit, readable MariaDB 10.11 SQL. Incremental only in
  tidy; full transactional replacement for aggregates. No extra frameworks,
  state tables or audit systems unless requested.
- Read [README.md](README.md) and the relevant [docs](docs/) before editing.
  Check Git status and preserve unrelated changes. Work on one stream and
  layer at a time unless a broader change is requested.
- Raw and mapping tables are read only. Confirm the exact database and managed
  objects before database writes or deployment. Use the primary database for
  read-only data profiling.
- Preserve documented keys, UTC boundaries, units, cleaning rules, weighting
  and coverage. Do not invent sensor meanings or scientific thresholds.
  Keep study filters and model variables outside the core ETL.
- Use explicit SQL column lists. Validate SQL changes with small synthetic
  fixtures, including duplicates, missing values, boundaries and row counts.
  Report what was tested; never report empty output or failed runs as success.
- Never commit credentials, participant data, raw extracts or local logs.
  Keep connection targets in local configuration; never put passwords on the
  command line.
- Keep documentation concise and aligned with code. Show the proposed commit
  message before committing; keep it to one or two lines.

Technical references: [architecture](docs/architecture.md),
[tidy cleaning](docs/tidy-cleaning.md), [aggregations](docs/aggregations.md),
[permissions](docs/database-permissions.md), [installation](docs/install-etl.md).
