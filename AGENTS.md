# Project instructions

## Purpose

This repository contains the MariaDB ETL that transforms raw TRIGGER sensor
data into small, understandable, analysis-ready datasets.

Change and validate one stream and one layer at a time unless the user
explicitly requests a cross-cutting change.

## Implemented architecture

- GPS, MyAir, SmartwatchLow and SmartwatchHigh implement tidy minute,
  five-minute, hourly and daily layers.
- Sleep implements its natural participant-night tidy layer only.
- Tidy procedures automatically choose full or incremental refresh.
- Five-minute, hourly and daily procedures use transactional full replacement.
- The five-minute bucket is the common analytical unit and all temporal
  boundaries are UTC.
- Higher-level means use equal temporal-unit weighting: equal minutes inside a
  bucket, equal observed buckets inside an hour and equal observed hours inside
  a day.
- Daily general and measurement-specific profiles contain exactly 24
  five-minute bucket counts ordered from hour 00 through 23.
- The definitive shared policy is in `docs/architecture.md`; stream-specific
  cleaning evidence is in the tidy specifications and shared aggregate
  behaviour is in `docs/aggregations.md`.

## Working method

Before changing the project:

1. Read this file, the root `README.md` and
   `docs/database-permissions.md` completely.
2. Inspect the current Git status and preserve unrelated user changes.
3. State which single stream and layer are in scope.
4. Read the relevant raw schema and the analyses that consume the output.
5. Write down the intended grain, key, retained columns, exclusions, units and
   expected row-loss diagnostics before implementing SQL.

Prefer the smallest complete step. Do not mix unrelated orchestration, layers
or streams into a focused data-definition change.

## Data-layer boundaries

The implemented high-level flow is:

```text
raw -> tidy -> canonical 5-minute -> optional hourly/daily -> analysis marts
```

Sleep is naturally participant-night data and may follow a separate path.

Raw database tables are the immutable source of truth. ETL code may read them
but must never modify, truncate, alter or drop them.

## Conservative and destructive tidy policy

The tidy layer is intentionally curated and may be destructive. It is not a
lossless copy of raw data.

For each stream, tidy should retain only the columns, rows and measurements
that have a documented downstream purpose. It may:

- omit unused raw columns;
- exclude rows with missing or unusable analytical keys;
- exclude ambiguous duplicates when no scientifically defensible selection
  rule exists;
- exclude devices whose participant binding cannot be resolved;
- replace invalid measurements with `NULL`, or exclude the row, when the
  stream specification explicitly requires it;
- normalize types, names and units needed by downstream analyses.

Do not preserve parallel raw and cleaned copies inside tidy merely for
completeness. The raw tables already provide recoverability. Do not introduce
quarantine tables, detailed row-level rejection storage or a generic quality
framework unless the user explicitly asks for them.

Destructive does not mean silent. Before discarding data:

- give the rule a clear name;
- document its unit and rationale;
- define whether it affects one value or the whole row;
- report at least source and final row counts during routine execution;
- calculate per-rule exclusion counts during focused validation when needed;
- verify the rule against representative data from the primary database;
- ensure the raw source remains untouched and recoverable.

Avoid speculative validity filters. If the sensor semantics or threshold are
not known, stop at a minimal technical rule and document the unresolved
decision rather than inventing a scientific cutoff.

## Analytical requirements

The analysis-ready tables follow these requirements:

- the shared temporal unit is a fixed five-minute bucket;
- timestamps and bucket boundaries use UTC as documented in the architecture;
- the participant-level analytical key is `userId` plus the appropriate time
  bucket;
- `deviceId` and `firmware` are provenance attributes, not automatically the
  participant-level analytical grain;
- a multi-device and firmware-transition policy must be decided before a
  canonical participant-level table is created;
- join cardinality between analysis-ready streams must be testable as
  one-to-one on `userId` and the time bucket;
- coverage is based on observed time buckets, not raw-reading density;
- raw-reading and bucket counts required to assess temporal coverage should be
  retained;
- no minimum coverage threshold belongs in the core ETL;
- the analysis date window after 2025-03-01 and before the current date remains
  an analysis rule, not a destructive ETL filter;
- within-subject centering, Humidex, pulse pressure, statistical bins and model
  variables remain analysis-specific unless explicitly promoted to a mart.

Do not assume that steps or calories are increments, cumulative counters or
sums. Raw profiling observed repeated values within five-minute intervals, so
the implemented policy uses a bucket mean and does not sum repeated copies.

## Deduplication and participant binding

Every deduplication rule must define:

- the exact duplicate key;
- whether equal and conflicting duplicates are treated differently;
- the deterministic selection or exclusion rule;
- aggregate row counts lost at each stage;
- boundary cases involving missing timestamps or upload times.

The current mapping tables have no validity intervals. Exclude a device over
its complete history when it maps to multiple participants; do not silently
select one participant or infer reassignment dates.

## Materialization and execution safety

- Treat the primary TRIGGER database as the authoritative source for data
  distributions, edge cases and transformation design. Smaller internal copies
  must not be assumed to represent the real data.
- Read-only investigation may target the primary database directly.
- Any operation that creates, replaces or removes database objects must name
  its exact target and require an unmistakable confirmation.
- Keep database names and internal environment topology out of versioned code
  and public documentation. Supply connection targets through local runtime
  configuration.
- Mirroring an approved definition to any additional internal database is an
  operational follow-up; it must use the same reviewed SQL rather than a
  separate implementation.
- Do not replace a valid table with `DROP TABLE` followed by a long rebuild.
  For a small table, transactional `DELETE` plus `INSERT` is acceptable and
  easier to understand. Introduce shadow tables only when size or locking makes
  the simpler transaction impractical.
- Use one common source cutoff for all streams in a run when cross-stream
  consistency matters.
- Tidy incremental processing uses its documented ingestion watermark and
  affected-key rebuild. Five-minute, hourly and daily layers remain full
  replacements because output watermarks cannot detect upstream deletions.
- A skipped run, empty output or failed validation must not be reported as a
  successful run.

## SQL conventions

- Target MariaDB 10.11 unless the user changes the requirement.
- Use explicit column lists in `INSERT` and `SELECT` statements.
- Use descriptive snake_case names for new ETL metadata and helper objects.
- Keep keys, units and null behaviour explicit in comments.
- Avoid `SELECT *` in persistent transformations.
- Keep each SQL file focused on one table or one narrowly defined reusable
  object.
- Avoid duplicated schema definitions when a single authoritative definition
  is practical.
- Prefer normalized coverage tables over thousands of manually repeated
  expressions; derive JSON profiles only when an actual consumer needs them.

## Validation

Use small synthetic fixtures. Never copy participant-level real data into
tests, documentation or commits.

At minimum, validate:

- output key uniqueness;
- missing key handling;
- equal and conflicting duplicates;
- device-to-participant cardinality;
- invalid and boundary measurement values;
- timestamp and five-minute bucket boundaries;
- row counts before and after destructive tidy steps;
- null, minimum, mean, maximum and count consistency;
- coverage counts within their physical limits;
- expected join cardinality with downstream tables.

Run the narrowest check first. When possible, compile and execute SQL against a
temporary local MariaDB instance before considering a definition complete.

## Observability

Keep observability simple. Each executable step should return:

- start and finish time;
- source and output row counts;
- the number of affected time partitions;
- source, deleted, inserted and final row counts.

Do not add a generic audit platform without a concrete operational use.
Persistent run history is outside the implemented design.

## Privacy and security

- Never commit credentials, participant data, raw extracts or local logs.
- Do not pass passwords on the command line.
- Do not expose email when analyses only require a participant identifier and
  nationality.
- Treat GPS and health measurements as sensitive data.
- Use pseudonymous identifiers in examples and reports.
- Keep diagnostic exports outside the repository and require an explicit output
  directory.

## Documentation decisions to preserve

Document each agreed decision close to its implementation, especially:

- table grain and primary key;
- timezone;
- device and firmware policy;
- retained and discarded columns;
- validation ranges and units;
- step and calorie semantics;
- sleep reference-date semantics;
- temporal weighting of hourly and daily means;
- coverage definitions.

Do not silently change any of these once analyses depend on them.

## Completion checklist for each new layer

Before calling a layer complete, verify that:

- its purpose and downstream consumer are known;
- its grain and key are documented and enforced;
- destructive tidy rules are documented and aggregate row loss is visible;
- raw tables remain untouched;
- timezone and units are explicit;
- the SQL passes a synthetic execution test;
- the output supports the expected analysis without ad hoc duplicate removal;
- documentation matches the implemented behaviour;
- no unrelated next layer was added prematurely.
