# `gps_5min` data specification

## Purpose and grain

`gps_5min` is the canonical five-minute GPS layer derived only from
`gps_tidy`.

```text
grain:       participant x UTC five-minute bucket
primary key: (userId, bucket_5min)
```

Every tidy minute belongs to exactly one bucket. The transformation aggregates
minutes but does not apply a minimum-coverage, study-area, date-window,
movement, speed or maximum-accuracy filter.

## Source

The source is the rebuilt tidy table:

```text
gps_tidy
  userId, minute_ts, bucket_5min, created_at,
  deviceId, firmware, longitude, latitude, accuracy
```

`bucket_5min` is already an explicitly constructed UTC boundary. This layer
does not derive it again and never reads the raw `gps` table.

## Output columns

| Column | Meaning |
|---|---|
| `userId` | Pseudonymous participant identifier |
| `bucket_5min` | Beginning of the UTC five-minute interval |
| `source_created_at_max` | Greatest tidy ingestion timestamp represented by the bucket |
| `observed_minute_n` | Number of distinct observed tidy minutes, from 1 through 5 |
| `device_n` | Number of distinct source devices represented |
| `firmware_n` | Number of distinct firmware values represented |
| `deviceId` | Device identifier only when `device_n = 1`, otherwise `NULL` |
| `firmware` | Firmware only when `firmware_n = 1`, otherwise `NULL` |
| `longitude_mean`, `longitude_min`, `longitude_max` | Longitude summaries in decimal degrees |
| `latitude_mean`, `latitude_min`, `latitude_max` | Latitude summaries in decimal degrees |
| `accuracy_mean`, `accuracy_min`, `accuracy_max` | Available horizontal-accuracy summaries in metres |
| `accuracy_n` | Number of minutes contributing a non-null accuracy |

`observed_minute_n` measures temporal coverage, not raw-upload density. Because
`gps_tidy` has at most one position per participant-minute, each represented
minute contributes exactly once.

## Aggregation rules

Coordinates use an unweighted arithmetic mean plus minimum and maximum. This
preserves compatibility with the analyses that consume `longitude_mean` and
`latitude_mean`, while the extrema expose within-bucket spread. The mean is a
short-interval descriptive position, not a trajectory or distance estimate.

Accuracy summaries ignore tidy `NULL` values. When no accuracy is available,
`accuracy_n` is zero and all three accuracy summaries are `NULL`. Coordinates
remain available independently of accuracy.

Device and firmware are provenance rather than analytical keys. A transition
inside a bucket does not destroy its valid participant-level positions:
instead, the count records the transition and the corresponding scalar
identifier becomes `NULL`. No arbitrary device or firmware is selected.

## Row-count behaviour

The five-minute transformation performs no additional row exclusion. It
reduces tidy rows only through temporal aggregation:

```text
source rows = rows in gps_tidy
output rows = distinct (userId, bucket_5min) keys in gps_tidy
```

For every output row:

- `observed_minute_n` is between 1 and 5;
- `accuracy_n` is between 0 and `observed_minute_n`;
- coordinate summaries stay inside physical longitude and latitude bounds;
- provenance identifiers are populated exactly when their distinct count is
  one.

## Refresh model

The initial procedure is deliberately full-only and parameterless:

```sql
CALL etl_gps_5min();
```

It reads one consistent `gps_tidy` snapshot, deletes the prior aggregate and
inserts the complete new aggregate in one transaction. An SQL error rolls back
both operations and preserves the prior valid table. An empty source raises an
error before deletion.

A full rebuild is used first because a downstream watermark based only on
currently present tidy rows cannot detect a tidy row that was removed during a
later correction. Incremental materialization therefore requires either an
affected-key handoff/change log or a comparison against the complete source.
Neither mechanism is introduced until the full transformation is
operationally correct and its runtime is measured.

The procedure returns start and finish timestamps, source rows, source bucket
count, deleted rows, inserted rows and final rows. No persistent run log or
state table is created.

## Limitations

- Arithmetic coordinate means need special treatment near the antimeridian;
  no such correction is introduced without evidence that the study data need
  it.
- Minimum and maximum coordinates describe a bounding box, not travelled
  distance.
- `source_created_at_max` is diagnostic freshness metadata, not a sufficient
  deletion-aware incremental state.
- Scheduled execution must not overlap the tidy refresh that supplies its
  source.
- An older incompatible `gps_5min` table must be replaced explicitly before
  first deployment; `CREATE TABLE IF NOT EXISTS` does not migrate it.
