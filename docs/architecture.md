# Architecture

The ETL uses one table and one parameterless `etl_<table>()` procedure per output.
Definitions live in [`etl/sql/`](../etl/sql/). Raw and `user_<stream>` mapping
tables are read only; only ETL outputs are replaced.

| Layer | Primary key | Refresh |
|---|---|---|
| Sensor tidy | `(userId, minute_ts)` | Full when empty; otherwise incremental |
| Sleep tidy | `(userId, date)` | Full when empty; otherwise incremental |
| Five-minute | `(userId, bucket_5min)` | Full transactional replacement |
| Hourly | `(userId, hour_ts)` | Full transactional replacement |
| Daily | `(userId, date)` | Full transactional replacement |

Event times without an offset are interpreted as UTC by convention.
Raw `created_at` is read in UTC as ingestion time. Sleep uses a raw reference
date whose start-night or wake-up meaning remains unresolved.

## Tidy refresh

Each call freezes its raw maximum `created_at`. Incremental selection uses
`created_at >= MAX(tidy.created_at)` and rebuilds complete affected keys from
raw history up to that cutoff:

| Stream | Rebuilt scope |
|---|---|
| GPS, MyAir | Event dates, across participants |
| SmartwatchLow, SmartwatchHigh | Participant-minutes |
| Sleep | Participant/reference-date pairs |

The inclusive boundary catches later arrivals with the same timestamp, but
repeats some work even without new uploads. Older ingestion timestamps and
mapping-only changes are not detected; excluded uploads may be reconsidered.
Each stream has its own cutoff: a run is not a simultaneous cross-stream snapshot.

## Transactions and diagnostics

GPS and Sleep tidy, all tidy increments, and all aggregates use transactional
replacement. MyAir and smartwatch full builds commit per participant to bound
lock usage; ordinary SQL errors trigger cleanup of partial output.

**After a crash or forced disconnection during a batched full build, partial
output must be explicitly emptied before retrying.** A non-empty table selects
incremental mode. Any deliberate full rebuild also requires emptying its target.
Confirm the exact database and managed table before that operation.

Every procedure returns timing and source, deleted, inserted and final row
counts, plus the affected time scope. Empty tidy output is an error in either
mode; incremental validation precedes commit. Aggregates reject empty sources
and check expected output counts before commit. There is no persistent run log.

Data rules: [tidy cleaning](tidy-cleaning.md) and [aggregations](aggregations.md).
Execution and recovery: [install and run](install-etl.md).
