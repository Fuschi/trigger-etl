# ETL architecture and data policy

## Flow

```text
raw → tidy participant-minutes → 5-minute buckets → hours → days
```

Sleep is already a nightly summary and ends at `sleep_tidy`.

| Layer | Primary key | Refresh |
|---|---|---|
| Tidy | `(userId, minute_ts)` | Full when empty, otherwise incremental |
| Sleep tidy | `(userId, date)` | Full when empty, otherwise incremental |
| Five-minute | `(userId, bucket_5min)` | Full transactional rebuild |
| Hourly | `(userId, hour_ts)` | Full transactional rebuild |
| Daily | `(userId, date)` | Full transactional rebuild |

Raw tables are read only and remain the source of truth.

## Temporal aggregation

Five minutes are the common interval because they are the minimum common
interval across the devices. Higher layers give equal weight to each observed
temporal unit: one- and five-minute buckets are equivalent in hourly means,
and sparse and complete hours are equivalent in daily means. This is a project
simplification, not a claim of statistical optimality. See
[`aggregations.md`](aggregations.md) for keys, coverage and stream-specific
rules.

## Cleaning and deduplication

Tidy is curated and can discard data. The common rules are:

1. Require device, firmware, event time and ingestion time.
2. For `(deviceId, firmware, event_ts)`, retain the earliest upload.
3. Collapse equal copies of that upload.
4. Exclude the event if equal-time copies disagree.
5. Exclude minutes with multiple unresolved events or provenance candidates.
6. Convert an invalid measurement to `NULL` when the rest of the row remains
   usable.
7. Exclude the row when no retained measurement remains usable.
8. Keep only devices with one participant mapping over the available history.

The exact order and measurement rules are documented in each tidy
specification. GPS requires valid coordinates. Sleep instead retains the
latest visible version of each nightly summary and excludes inconsistent
duration totals.

| Problem | Result |
|---|---|
| Equal duplicate | Extra copy removed |
| Conflicting duplicate | Event removed |
| Invalid independent value | Value set to `NULL` |
| No usable value | Row removed |
| Missing participant mapping | Device observations removed |
| Ambiguous participant mapping | Complete device history removed |
| Multiple device/firmware candidates in one participant-minute | Minute removed |
| Inconsistent Sleep duration identity | Nightly summary removed |

There are no quarantine or row-level rejection tables. Procedures return
aggregate source, deleted, inserted and final counts. Detailed rule-level
losses are calculated during focused validation.

## Measurement policy

Filters are technical, not clinical:

- GPS requires valid longitude and latitude; non-positive accuracy becomes
  `NULL`.
- MyAir removes documented sentinels and values outside the specified
  humidity and pressure bounds.
- SmartwatchLow cleans invalid pressure pairs and negative activity values.
  `bodytemp` and `skintemp` remain on their unresolved raw sensor scales.
- SmartwatchHigh treats zero heart rate and oxygen as unavailable;
  breathing-rate codes `-1`, `0` and `255` are unavailable; sleep-state code
  `0` is retained.
- Sleep durations must be between 0 and 1,440 minutes and must satisfy the
  documented total/component identity.

Exact limits and unresolved units are recorded in the tidy specifications.

## Time and joins

Raw `created_at` values are read as UTC and used for ingestion ordering.
`event_ts`, `minute_ts`, `bucket_5min`, `hour_ts` and daily boundaries are
interpreted as UTC.

The four five-minute sensor tables enforce one row per
`(userId, bucket_5min)`, preventing many-to-many expansion when joined on that
complete key. Join type and coverage requirements remain analysis choices.

The Sleep date is only a raw reference date; the source does not establish
whether it is the sleep-start or wake-up date.

## Refresh behaviour

Tidy procedures have no parameters. An empty output triggers a full build;
otherwise `MAX(tidy.created_at)` is the watermark and affected dates or
minutes are rebuilt from raw history.

Known limits of this simple watermark are:

- rows added later with the same maximum `created_at` are not detected;
- backfilled rows with an older `created_at` are not detected;
- mapping-only changes are not detected;
- excluded newest rows can be reconsidered on later runs.

Five-minute, hourly and daily procedures use full rebuilds so upstream
deletions cannot leave stale aggregates.

Large tidy full builds commit by participant and are not globally atomic. An
interrupted full build must be emptied and restarted. Each stream also freezes
its own cutoff, so one nightly run is not a simultaneous cross-stream snapshot.

## Operations

- Installation: [`install-etl.md`](install-etl.md)
- Nightly runner: [`../etl/run_etl.sh`](../etl/run_etl.sh)
- Cron example: [`../etl/crontab.example`](../etl/crontab.example)
- Privileges: [`database-permissions.md`](database-permissions.md)

The core ETL does not apply study dates, minimum coverage, cohort criteria,
Humidex, pulse pressure, centring, exposure categories or other
analysis-specific transformations.
