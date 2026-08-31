# `myair_5min` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

## Purpose and grain

`myair_5min` is the canonical five-minute environmental layer derived only
from `myair_tidy`.

```text
grain:       participant x UTC five-minute bucket
primary key: (userId, bucket_5min)
```

The table contains every bucket represented by at least one tidy minute. It
does not apply a minimum-coverage, date-window or exposure threshold.

## Source and retained measurements

The source is:

```text
myair_tidy
  userId, minute_ts, bucket_5min, created_at, deviceId, firmware,
  pm1, pm25, pm10,
  pc03, pc05, pc1, pc25, pc5, pc10,
  temperature, humidity, pressure, sound, uvb, light
```

The tidy layer has already converted documented technical errors to `NULL` and
has at most one row per participant-minute. Five-minute aggregation does not
reapply or broaden those cleaning rules.

## Output structure

Every measurement has four output columns:

```text
<measurement>_mean
<measurement>_min
<measurement>_max
<measurement>_n
```

The first three summarize the non-null tidy values in the bucket.
`<measurement>_n` is the number of observed minutes contributing to that
measurement, from zero through five. When it is zero, all three statistics are
`NULL`.

The retained measurements and documented interpretations are:

| Group | Measurements | Unit or interpretation |
|---|---|---|
| Particulate mass | `pm1`, `pm25`, `pm10` | µg/m³ |
| Particle counts | `pc03`, `pc05`, `pc1`, `pc25`, `pc5`, `pc10` | Sensor counts; exact normalization unresolved |
| Environment | `temperature` | Recorded temperature; expected °C |
| Environment | `humidity` | Relative humidity, percent |
| Environment | `pressure` | hPa |
| Environment | `sound` | Recorded sound value; exact unit unresolved |
| Environment | `uvb` | Sensor units |
| Environment | `light` | Recorded light value; expected lux |

The table also retains:

- `source_created_at_max`, the greatest tidy ingestion timestamp represented;
- `observed_minute_n`, the number of distinct tidy minutes from one through
  five;
- distinct device and firmware counts;
- scalar `deviceId` and `firmware` only when the corresponding count is one.

Calendar date, hour and minute are not duplicated because they are derivable
from `bucket_5min`.

## Aggregation and provenance

All means are unweighted arithmetic means across tidy minutes. This prevents
raw upload density from changing the temporal weight of a minute. Minima,
maxima and counts preserve within-bucket variation and availability for later
quality checks.

A participant may cross a device or firmware boundary inside five minutes.
Such a bucket remains analytically valid: its provenance count records the
transition, while the scalar provenance value becomes `NULL`. No device or
firmware is selected arbitrarily.

No five-minute Humidex, exposure category, saturation flag or scientific
threshold is added. Those remain analysis-specific unless a later reviewed
mart requires them.

## Row-count and value invariants

There is no additional row exclusion:

```text
source rows = rows in myair_tidy
output rows = distinct (userId, bucket_5min) keys in myair_tidy
```

For every measurement, its count cannot exceed `observed_minute_n`. A positive
count requires non-null minimum, mean and maximum ordered as
`minimum <= mean <= maximum`; a zero count requires all three to be `NULL`.

## Refresh model

The procedure is parameterless and uses a full replacement:

```sql
CALL etl_myair_5min();
```

It reads one consistent `myair_tidy` snapshot and replaces the aggregate with
transactional `DELETE` plus `INSERT`. An empty source raises an error before
deletion, and an SQL error rolls back the complete replacement.

The full rebuild is the implemented correctness policy. A watermark over
currently present tidy rows cannot detect that an older tidy row was removed
by a correction, and this layer has no separate deletion log.

The procedure returns start and finish time, source rows, distinct source
buckets, deleted rows, inserted rows and final rows. It creates no persistent
state or run history.

## Limitations

- Measurement means describe available minutes only; the corresponding counts
  are required to interpret partial availability.
- A bucket with one observed minute is retained exactly like a bucket with five
  observed minutes; coverage filtering belongs downstream.
- `source_created_at_max` is freshness metadata, not deletion-aware state.
- Runtime and lock use must be monitored because the replacement is one
  transaction.
- The procedure must not overlap `etl_myair_tidy()`.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible existing
  schema; schema replacement is a separate installation operation.
