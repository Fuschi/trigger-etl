# `smartwatchlow_5min` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

## Purpose and grain

`smartwatchlow_5min` is the canonical five-minute activity, blood-pressure and
temperature-labelled sensor layer derived only from `smartwatchlow_tidy`.

```text
grain:       participant x UTC five-minute bucket
primary key: (userId, bucket_5min)
```

Every bucket represented by at least one tidy minute is retained. No
minimum-coverage, date-window or clinical threshold is introduced here.

## Source and measurements

```text
smartwatchlow_tidy
  userId, minute_ts, bucket_5min, created_at, deviceId, firmware,
  step, cal, bphigh, bplow, bodytemp, skintemp
```

For each of the six measurements the output stores:

```text
<measurement>_mean
<measurement>_min
<measurement>_max
<measurement>_n
```

The count is the number of non-null tidy minutes contributing to that
measurement. A zero count requires all three statistics to be `NULL`.

## Step and calorie policy

The complete raw profile showed that `step` and `cal` are almost always
repeated within their five-minute interval and rise and fall between adjacent
buckets. Summing minute copies would therefore multiply the recorded value.

This layer uses the arithmetic mean as the bucket estimate and retains minimum,
maximum and count to expose the rare within-bucket disagreements. It does not
retain sums, first values or last values, and it does not claim that either
measurement is a cumulative counter. The calorie unit is not established, so
the ETL keeps the recorded sensor scale without labelling it as kcal.

## Other measurement policy

`bphigh` and `bplow` remain a paired measurement: their counts must be equal
and their bucket means preserve `bphigh_mean >= bplow_mean`. Pulse pressure
remains analysis-specific.

`bodytemp` and `skintemp` are aggregated exactly as retained by tidy, including
zero and values above 45. Their meaning and unit remain unresolved.

## Coverage and provenance

`observed_minute_n` counts distinct tidy minutes from one through five.
Measurement counts cannot exceed it. `source_created_at_max` records the
freshest tidy ingestion timestamp represented.

Device and firmware counts expose transitions inside a bucket. The scalar
`deviceId` or `firmware` is populated only when its distinct count is one;
otherwise it is `NULL`. A transition does not destroy otherwise valid
participant-level measurements.

## Row-count behaviour

The layer performs no new row exclusion:

```text
source rows = rows in smartwatchlow_tidy
output rows = distinct (userId, bucket_5min) keys in smartwatchlow_tidy
```

Null measurements are summarized independently, so one unavailable variable
does not remove the bucket or another available variable.

## Refresh model

The procedure is a parameterless full rebuild:

```sql
CALL etl_smartwatchlow_5min();
```

It uses a consistent tidy snapshot and transactional `DELETE` plus `INSERT`.
An empty source fails before deletion; any SQL error rolls back to the previous
complete aggregate. It returns source rows, distinct source buckets, deleted,
inserted and final row counts together with UTC start and finish times.

Full replacement is the implemented correctness policy because a watermark
over current tidy rows cannot detect a tidy row removed by a correction. This
layer does not maintain separate deletion state.

## Limitations

- Means describe only available minutes; counts are required to interpret
  incomplete buckets.
- Step and calorie means describe the recorded bucket-level scale; they are not
  interpreted as totals or cumulative counters.
- `source_created_at_max` is not sufficient incremental state.
- Runtime and lock use must be monitored because the replacement is one
  transaction.
- The procedure must not overlap `etl_smartwatchlow_tidy()`.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible existing
  schema; schema replacement is a separate installation operation.
