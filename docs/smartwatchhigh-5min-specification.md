# `smartwatchhigh_5min` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

## Purpose and grain

`smartwatchhigh_5min` is the canonical five-minute cardiovascular,
respiratory and sleep-state layer derived only from `smartwatchhigh_tidy`.

```text
grain:       participant x UTC five-minute bucket
primary key: (userId, bucket_5min)
```

Every bucket represented by at least one tidy minute is retained. No
minimum-coverage, date-window or clinical threshold is added.

## Source

```text
smartwatchhigh_tidy
  userId, minute_ts, bucket_5min, created_at, deviceId, firmware,
  heartrate, oxygens, breathrate, sleeprate
```

The tidy layer has already converted technical missing and error codes to
`NULL`, while preserving valid sleep-state code zero.

## Continuous measurements

Heart rate, oxygen saturation and breathing rate each produce:

```text
<measurement>_mean
<measurement>_min
<measurement>_max
<measurement>_n
```

The statistics use non-null tidy minutes. A zero count requires all three
statistics to be `NULL`; a positive count requires
`minimum <= mean <= maximum`. Means are unweighted across minutes, so raw
upload density cannot change a minute's temporal weight.

## Categorical sleep state

`sleeprate` is not averaged. Its unresolved raw codes are represented through:

```text
sleeprate_n
sleeprate_0_n
sleeprate_1_n
sleeprate_2_n
sleeprate_3_n
sleeprate_4_n
```

`sleeprate_n` counts all non-null sleep-state minutes and equals the sum of the
five code counts. Code zero is deliberately retained as an observed category.
No dominant state is selected because ties would require an arbitrary rule and
the code labels are not established by a device codebook.

## Coverage, provenance and firmware availability

`observed_minute_n` counts distinct tidy minutes from one through five.
Measurement counts cannot exceed it. `source_created_at_max` records the
freshest represented tidy ingestion timestamp.

Device and firmware counts expose transitions inside a bucket. Scalar
provenance is present only when its distinct count is one; otherwise it is
`NULL` and the participant-level bucket remains available.

This is important because the two profiled firmware versions expose nearly
complementary variables: one generally supplies breathing rate and the other
sleep state. The five-minute layer summarizes whatever each minute actually
contains and does not interpret firmware-related absence as physiology.

## Row-count behaviour

No further row exclusion is applied:

```text
source rows = rows in smartwatchhigh_tidy
output rows = distinct (userId, bucket_5min) keys in smartwatchhigh_tidy
```

A bucket remains present even when only one of the four measurements is
available.

## Refresh model

The parameterless procedure performs a full rebuild:

```sql
CALL etl_smartwatchhigh_5min();
```

It reads a consistent tidy snapshot and replaces the managed aggregate through
transactional `DELETE` plus `INSERT`. Empty source data raises an error before
deletion; any SQL error rolls back the previous complete table. The returned
summary reports UTC start and finish, source rows, distinct source buckets,
deleted, inserted and final rows.

Full replacement is the implemented correctness policy. A maximum timestamp
from currently present tidy rows cannot detect a tidy row removed by a later
correction, and this layer keeps no separate deletion state.

## Limitations

- Means and state counts describe available minutes only; coverage counts must
  accompany interpretation.
- Sleep-state code labels are unresolved and must remain neutral.
- `source_created_at_max` is freshness metadata, not deletion-aware state.
- Runtime and lock use must be monitored because the replacement is one
  transaction.
- The procedure must not overlap `etl_smartwatchhigh_tidy()`.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible existing
  schema; schema replacement is a separate installation operation.
