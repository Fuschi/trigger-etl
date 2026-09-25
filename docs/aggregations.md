# Aggregations

GPS, MyAir, SmartwatchLow and SmartwatchHigh follow this chain:

```text
<stream>_tidy → <stream>_5min → <stream>_hourly → <stream>_daily
```

| Layer | Primary key | Source | Mean weighting |
|---|---|---|---|
| Five-minute | `(userId, bucket_5min)` | Tidy | Equal available minutes |
| Hourly | `(userId, hour_ts)` | Five-minute | Equal available bucket means |
| Daily | `(userId, date)` | Hourly | Equal available hourly means |

All boundaries are UTC. Five minutes is the shared analytical interval;
joining sensor tables on `(userId, bucket_5min)` cannot multiply matching rows.
Sleep ends at tidy. Refresh and transaction rules are in [architecture](architecture.md).

## Statistics

Continuous measurements retain mean, minimum, maximum and availability counts.
Means ignore `NULL`; extrema propagate lower-layer minima/maxima. There are no
additional cleaning rules or minimum-coverage filters.

A bucket with one minute and a bucket with five minutes have equal hourly
weight. An hour with one bucket and an hour with twelve have equal daily weight.
For example, hourly means 10 and 30 produce a daily mean of 20 regardless of
their coverage. This is a project convention, not a completeness adjustment.

| Stream | Specific behavior |
|---|---|
| GPS | Arithmetic coordinate and accuracy statistics; not distance or trajectory estimates. Accuracy includes zero/negative raw values. |
| MyAir | All 15 measurements summarized independently. |
| SmartwatchLow | Step/cal remain means, never totals; pressure counts stay paired. Temperature-labelled values retain their raw scale. |
| SmartwatchHigh | Heart rate, oxygen and breathing rate use continuous statistics. `sleeprate_0_n`…`sleeprate_4_n` count observed minutes by code; no categorical mean. |

Units and retained fields: [tidy cleaning](tidy-cleaning.md#measurements).

## Coverage

| Layer | General counts | Per-measurement counts (`x`) |
|---|---|---|
| Five-minute | `observed_minute_n`: 1…5 | `x_n`: non-null minutes |
| Hourly | `observed_5min_n`: 1…12; `observed_minute_n`: up to 60 | `x_5min_n`, `x_minute_n` |
| Daily | `hours_n`: 1…24; `five_min_n`: up to 288; `minute_n`: up to 1440 | `x_hours_n`, `x_5min_n`, `x_minute_n` |

Counts describe observed time units, not raw upload density or measurement
quality. GPS coordinate and accuracy counts equal general coverage.
Daily `complete_hours_n` counts hours with 12 observed buckets, not necessarily
60 observed minutes; `x_complete_hours_n` applies the same rule to measurement x.

Daily `five_min_profile` and `x_5min_profile` are JSON arrays of 24 bucket counts
ordered 00…23 UTC. Entries range 0…12; missing hours are zero. Days without any
observations have no output row.

## Provenance

At five minutes, `device_n` and `firmware_n` count distinct identifiers.
Hourly `mixed_*_5min_n` counts mixed buckets. Daily `ambiguous_*_hour_n` counts
hours without a unique identifier; mixed-bucket counts are also retained.
Scalar `deviceId`/`firmware` is populated only when the whole period is
unambiguous. Counts of mixed periods are not distinct-device counts.
`source_created_at_max` is the greatest represented ingestion time, not run time.
