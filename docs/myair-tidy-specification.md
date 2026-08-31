# `myair_tidy` data specification

Shared cleaning, time and aggregation policy:
[`architecture.md`](architecture.md).

## Purpose

`myair_tidy` contains one unambiguous MyAir observation per participant and
UTC minute. It retains the environmental measurements needed by the canonical
five-minute analytical layer without keeping redundant calendar columns.

```text
grain:       participant x UTC minute
primary key: (userId, minute_ts)
```

The raw `myair` and `user_myair` tables remain read only. The tidy table is
deliberately selective and can always be rebuilt from raw data.

## Required source structure and interpretation

The SQL expects:

```text
myair
  deviceId, firmware, event_ts, created_at,
  pm1, pm25, pm10,
  pc03, pc05, pc1, pc25, pc5, pc10,
  temperature, humidity, pressure, sound, uvb, light

user_myair
  deviceId, userId
```

The definition requires `event_ts` to be a `DATETIME` and `created_at` to be a
`TIMESTAMP`. It reads `created_at` with the MariaDB session set to UTC before
storing it in tidy `DATETIME(6)`. The source event time carries no timezone
offset, so the ETL explicitly interprets it as UTC.

`created_at` is treated as an immutable ingestion timestamp. The mapping table
does not provide validity intervals; only devices associated with exactly one
participant over the available mapping history are retained.

## Output columns

| Column | Meaning |
|---|---|
| `userId` | Participant identifier |
| `minute_ts` | Beginning of the UTC event minute |
| `bucket_5min` | Beginning of the containing UTC five-minute bucket |
| `event_ts` | Original event timestamp |
| `created_at` | Original ingestion timestamp normalized to UTC; incremental reference |
| `deviceId` | Device provenance |
| `firmware` | Firmware provenance |
| `pm1`, `pm25`, `pm10` | Particulate mass in micrograms per cubic metre |
| `pc03`, `pc05`, `pc1`, `pc25`, `pc5`, `pc10` | Particle counts, historically documented as counts per decilitre |
| `temperature` | Temperature on the recorded sensor scale; no scientific validity range is imposed |
| `humidity` | Relative humidity in percent |
| `pressure` | Pressure in hPa |
| `sound` | Sound on the recorded sensor scale |
| `uvb` | UVB on the recorded sensor scale |
| `light` | Light on the recorded sensor scale |

The separate `date`, `hour`, `minute` and `second` columns from the historical
tidy table are omitted because they can be derived from `event_ts` or
`minute_ts`.

## Deduplication and row exclusions

The transformation applies these rules in order:

1. Exclude rows missing `deviceId`, `firmware`, `event_ts` or `created_at`.
2. For `(deviceId, firmware, event_ts)`, keep the earliest upload.
3. Collapse completely equal copies of that earliest upload.
4. Exclude the event if earliest copies disagree on any MyAir measurement.
5. Exclude a device/firmware-minute containing more than one event.
6. Keep only devices associated with exactly one non-null participant in
   `user_myair`.
7. Exclude a participant-minute containing candidates from multiple devices
   or firmware versions.
8. After value cleaning, exclude a row only when every retained measurement is
   `NULL`.

The participant-minute exclusion is conservative: the procedure does not
choose arbitrarily between multiple devices, firmware versions or events.

## Measurement cleaning

An invalid measurement becomes `NULL`; it does not remove the other valid
measurements in the same row.

| Measurements | Retained values | Reason |
|---|---:|---|
| `pm1`, `pm25`, `pm10` | `0` through `65534` | `65535` is confirmed as an isolated sensor error code in the raw profile |
| `pc03`, `pc05`, `pc1`, `pc25`, `pc5`, `pc10` | `0` through `65534` | `65535` is confirmed as an isolated sensor error code in the raw profile |
| `temperature` | any non-null recorded value | No defensible validity range has been confirmed; the observed raw range contains no sentinel pattern |
| `humidity` | `0` through `100` | Physical percent relative-humidity bounds |
| `pressure` | `300` through `1100` | Physical guard in hPa; every observed violation is the `65535` error code |
| `sound` | `0` through `200` | Empirical technical guard separating one isolated value of `1792` from the otherwise observed maximum of `110` |
| `uvb` | `0` through `6552` | Every observed violation is the `6553` error or missing-value code |
| `light` | values greater than or equal to `0` | Negative readings are technically invalid; the observed upper plateau is retained |

No additional scientific or exposure threshold is applied. Where a unit is
not established by device documentation, the output deliberately retains the
recorded sensor scale instead of assigning an unsupported physical meaning.

## Primary raw-data validation on 2026-08-24

A complete compressed raw MyAir dump was profiled in streaming mode without
loading participant-level data into memory or copying it into this repository.
The snapshot contained:

```text
raw rows:             54,451,379
distinct devices:           238
distinct firmware values:     3
```

All fifteen measurement columns were numeric and finite in every row. There
were no missing or blank `deviceId`, `firmware`, `event_ts` or `created_at`
values in the dump. These observations validate data completeness for this
snapshot, but do not replace direct verification of the MariaDB column types.

Exact minima, maxima and invalid-value counts were calculated over the entire
dump. The 1st and 99th percentiles below are approximate values from a fixed,
uniform sample of 200,000 rows.

| Measurement | Raw minimum | Approximate P1 | Approximate P99 | Raw maximum | Values made `NULL` |
|---|---:|---:|---:|---:|---:|
| `pm1` | 0 | 0 | 84 | 65535 | 23 |
| `pm25` | 0 | 0 | 146 | 65535 | 23 |
| `pm10` | 0 | 0 | 161 | 65535 | 30 |
| `pc03` | 0 | 0 | 14853 | 65535 | 11,290 |
| `pc05` | 0 | 0 | 4221 | 65535 | 30 |
| `pc1` | 0 | 0 | 1026 | 65535 | 30 |
| `pc25` | 0 | 0 | 115 | 65535 | 259 |
| `pc5` | 0 | 0 | 20 | 65535 | 259 |
| `pc10` | 0 | 0 | 10 | 65535 | 259 |
| `temperature` | -4.32 | 14.42 | 35.99 | 61.44 | 0 |
| `humidity` | 7 | 20.98 | 58 | 100 | 0 |
| `pressure` | 542 | 901 | 1023 | 65535 | 23 |
| `sound` | 0 | 40 | 82 | 1792 | 1 |
| `uvb` | 0 | 0 | 7 | 6553 | 386 |
| `light` | 0 | 0 | 5750.01 | 18905 | 0 |

The value checks affect 12,613 measurement cells in 11,647 raw rows. This is
0.00154% of all measurement cells and 0.0214% of raw rows. Invalid values are
cleaned independently, so these checks do not by themselves discard any row.
Their observed co-occurrence is:

| Invalid measurements in the same raw row | Rows |
|---|---:|
| `pc03` only | 11,260 |
| `pc25`, `pc5`, `pc10`, `uvb` | 229 |
| `uvb` only | 127 |
| all nine `pm`/`pc` values, `pressure`, `uvb` | 23 |
| `pm10`, `pc03`, `pc05`, `pc1`, `pc25`, `pc5`, `pc10`, `uvb` | 7 |
| `sound` only | 1 |

The particle and pressure violations are all exactly `65535`; the UVB
violations are all exactly `6553`. No negative value and no value above
`65535` was observed in those fields.

The `sound` profile provides empirical, but not device-documentation, support
for the technical upper guard. There are 22,089 values above `100`: all are
between `101` and `110` except one value of `1792`. The `200` threshold
therefore cleans that single isolated outlier without altering the observed
high end of the main distribution.

Temperature remains unfiltered. The dump contains 3,186 negative readings and
4,429 readings above `50`, with a continuous observed maximum of `61.44` and
no sentinel pattern. These readings may reflect real ambient conditions,
direct exposure or sensor heating; no tidy-layer exclusion is scientifically
justified.

Light also remains subject only to the non-negative technical guard. Its
maximum `18905` occurs in 85,854 rows, indicating a likely sensor saturation
plateau rather than an isolated error. The tidy layer retains this value; a
later aggregation or analysis may report saturation counts if they have a
concrete scientific use. In particular, `6553` must not be treated as a light
error code because many valid light readings extend above that value.

This snapshot validation concerns measurement ranges. Deduplication, mapping
and participant-minute exclusions are data-state-dependent and are assessed
separately through focused database queries and the procedure's aggregate run
summary; they are not persisted as a row-level rejection log.

## Database objects

The implementation uses only these persistent objects:

```text
myair_tidy
etl_myair_tidy()
```

It also creates three connection-local temporary helper tables: affected event
dates, unambiguous device mappings and participants selected for the current
run. No shadow table, separate watermark, rejected-row table or persistent
run-history table is created. Scheduled executions must not overlap.

## Full and incremental refresh

The procedure has no parameters:

```sql
CALL etl_myair_tidy();
```

When `myair_tidy` is empty, the call performs a full build. It processes one
participant at a time and commits after that participant is complete. This
bounds the number of InnoDB locks held by the full build and uses the existing
raw index whose first column is `deviceId`. If any full-build batch fails, the
error handler rolls back that batch and truncates the partial tidy output so
the next call starts in full mode again. Full error cleanup therefore requires
`DROP` on the managed `myair_tidy` table.

When `myair_tidy` is populated, the procedure uses
`MAX(myair_tidy.created_at)` as its ingestion watermark, finds raw rows with a
strictly greater `created_at` and completely rebuilds every event date touched
by those rows. The incremental delete and all participant inserts remain in
one InnoDB transaction, so an SQL failure rolls back the complete incremental
run.

Both modes freeze one raw maximum `created_at` at the start. The procedure
resolves the device map once per call and processes all devices belonging to a
participant together, so participant-minute ambiguity is still evaluated
across devices and firmware versions.

## Incremental limitations

- A raw row inserted later with exactly the current maximum `created_at` is not
  detected by the strict `>` comparison.
- Raw rows inserted later with a `created_at` older than the tidy maximum are
  not detected.
- If all newest raw rows are excluded, the tidy maximum does not advance and
  those rows are reconsidered on the next run.
- A change made only to `user_myair` is not detectable from MyAir ingestion
  time.
- A full build is intentionally not one atomic transaction. Ordinary SQL
  errors trigger automatic cleanup, but a server crash or forced connection
  termination may prevent the error handler from running. After such an
  interruption, empty `myair_tidy` explicitly before retrying the full build.
- Deliberately requesting another full refresh requires emptying the managed
  table before the next call.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible
  `myair_tidy`. Replacing its schema requires a separately confirmed database
  operation.

## Returned summary

Every call returns one non-persistent row containing:

```text
run_mode
started_at
finished_at
previous_created_at
raw_max_created_at
affected_days
source_rows
deleted_tidy_rows
inserted_tidy_rows
total_tidy_rows
```

The returned summary provides routine source and output counts. Per-rule
deduplication, mapping and ambiguity losses remain focused validation metrics,
not persistent ETL state.
