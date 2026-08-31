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

## Five-minute bucket

Five minutes are the common interval chosen for GPS, MyAir and smartwatch
data because they are the minimum common interval across the devices. This is
a project convention, not a claim of statistical optimality.

All buckets use UTC boundaries. A day can contain at most 288 five-minute
buckets. No minimum coverage is required by the ETL.

## Aggregation weights

The implemented aggregation is hierarchical:

```text
tidy → 5 minutes: mean of available participant-minutes
5 minutes → hour: mean of available 5-minute means
hour → day: mean of available hourly means
```

Each observed five-minute bucket has the same weight in the hourly mean. A
bucket based on one valid minute and a bucket based on five valid minutes are
therefore treated equally in higher aggregations.

Likewise, each observed hour has the same weight in the daily mean, regardless
of whether it contains one or twelve buckets.

This is an explicit simplification. The ETL does not claim that it is better
than weighting by the number of observations. Coverage columns retain the
number of minutes, buckets and hours so the choice can be reviewed in analyses.

Minima and maxima are propagated as extrema. Smartwatch sleep-state codes are
categorical and are counted, never averaged.

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

## Coverage and provenance

Coverage counts do not change aggregation weights:

- `observed_minute_n`: represented minutes in a five-minute bucket;
- `observed_5min_n`: represented buckets in an hour;
- `hours_n`, `five_min_n`, `minute_n`: represented units in a day;
- measurement-specific counts: non-null availability for that measurement.

Daily `*_5min_profile` columns are JSON arrays of 24 counts, ordered from UTC
hour 00 through 23. They contain coverage, not measurement values.

`deviceId` and `firmware` are provenance. Their scalar value is retained only
when the period is unambiguous; counts expose mixed periods.

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
