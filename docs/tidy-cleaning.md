# Tidy cleaning

Tidy retains one usable, unambiguous observation per analytical key. Discarded
values and rows remain recoverable from immutable raw tables.

## Output contract

| Streams | Key | Retained technical columns |
|---|---|---|
| GPS, MyAir, SmartwatchLow, SmartwatchHigh | `(userId, minute_ts)` | `bucket_5min`, `event_ts`, `created_at`, `deviceId`, `firmware` |
| Sleep | `(userId, date)` | `created_at`, `deviceId`, `firmware` |

Sensor minutes floor event timestamps to the minute; five-minute timestamps
floor them to multiples of five. UTC is the project convention.
Raw calendar components are omitted; Sleep derives `date` from them and drops
unreliable clock components. Retained measurements are listed below.

Each stream reads its raw table and `user_<stream>(deviceId, userId)` mapping.
Sensor sources require `event_ts` as `DATETIME` and `created_at` as `TIMESTAMP`;
Sleep constructs a valid date from `year`, `month`, `day`.
`deviceId` and `firmware` are provenance, not participant-level keys.

## Sensor exclusions

| Rule | Selection or exclusion |
|---|---|
| Required fields | Reject missing/blank device or firmware, missing event time or ingestion time. |
| Exact event | Key: `(deviceId, firmware, event_ts)`. Select earliest `created_at`; ignore later uploads. |
| Equal copies | Collapse identical retained payloads at that earliest time. |
| Conflicting copies | Reject the event if earliest payloads disagree, before value cleaning. |
| Device-minute ambiguity | Reject multiple remaining events for `(deviceId, firmware, minute_ts)`. |
| Measurement cleaning | Apply the rules below; reject rows with no usable measurement. GPS requires valid paired coordinates. |
| Participant binding | Keep devices mapped to exactly one distinct non-null `userId`; reject unmapped or ambiguous devices. No reassignment dates are inferred. |
| Participant-minute ambiguity | Reject minutes containing multiple remaining usable device/firmware candidates. |

All four sensor streams resolve mappings before event deduplication and assess
participant ambiguity after
removing unusable rows. Ambiguous bindings exclude complete device histories
when those histories are rebuilt; see [incremental limits](architecture.md#tidy-refresh).

## Measurements

Unless stated otherwise, an invalid value becomes `NULL`, preserving other
usable measurements in the row. These are technical rules, not clinical filters.

### GPS

| Fields | Rule | Unit |
|---|---|---|
| `longitude`, `latitude` | Both required; longitude −180…180 and latitude −90…90. Otherwise reject row. | Decimal degrees |
| `accuracy` | Copied unchanged, including zero/negative values; raw and tidy are `NOT NULL`. | Reported metres |

No geographic, speed or maximum-accuracy filter is applied. Accuracy counts
measure presence, not position quality.
[SQL](../etl/sql/gps_tidy.sql).

### MyAir

| Fields | Retained values | Unit / rationale |
|---|---|---|
| `pm1`, `pm25`, `pm10` | 0…65534 | µg/m³; excludes observed sentinel 65535 |
| `pc03`, `pc05`, `pc1`, `pc25`, `pc5`, `pc10` | 0…65534 | Historical count/dL; excludes 65535 |
| `temperature` | Unchanged | Recorded scale; unit/range unresolved |
| `humidity` | 0…100 | Relative humidity, % |
| `pressure` | 300…1100 | hPa; observed violations were 65535 |
| `sound` | 0…200 | Recorded scale; separates observed outlier 1792 from other values ≤110 |
| `uvb` | 0…6552 | Recorded scale; excludes observed code 6553 |
| `light` | ≥0 | Recorded scale; observed saturation plateau 18905 is retained |

[SQL](../etl/sql/myair_tidy.sql).

### SmartwatchLow

| Fields | Rule | Unit / interpretation |
|---|---|---|
| `step`, `cal` | Retain ≥0; no upper cutoff | Reported activity values; calorie unit unresolved |
| `bphigh`, `bplow` | Both must be positive; store greater then lower value, otherwise both `NULL` | Presumed mmHg; corrects firmware-specific reversal |
| `bodytemp`, `skintemp` | Unchanged, including zero | Raw scale; meaning and units unresolved |

Steps and calories repeat within five-minute periods. Their exact semantics
remain unresolved; aggregations use means, never sums of minute copies.
[SQL](../etl/sql/smartwatchlow_tidy.sql).

### SmartwatchHigh

| Field | Retained values | Unit / interpretation |
|---|---|---|
| `heartrate` | >0 | Beats/minute; zero unavailable, no upper cutoff |
| `oxygens` | 1…100 | Saturation, %; zero unavailable |
| `breathrate` | 1…100 | Breaths/minute; excludes −1, 0, 255 |
| `sleeprate` | Integer codes 0…4 | Categorical; −1 unavailable, stage labels unresolved |

Sleep code 0 is retained. Firmware `03.05.03` provides breathing rate but no
sleep state in the profiled snapshot; `03.05.03-6549` shows the reverse.
This difference is measurement availability, not a physiological change.
[SQL](../etl/sql/smartwatchhigh_tidy.sql).

### Sleep

Require a valid calendar date, non-blank device/firmware, ingestion time and
unambiguous participant binding. For `(deviceId, firmware, date)`, select the
**latest** upload, collapse equal copies and reject conflicting final payloads.
After cleaning, reject participant-dates with multiple remaining candidates.

| Fields | Rule | Unit / interpretation |
|---|---|---|
| `sleepduration` | 1…1440 | Apparent minutes; total includes `awake` |
| `awake`, `remsleep`, `lightsleep`, `deepsleep` | 0…1440 | Apparent minutes; zero is valid |
| `sleepquality` | 1…5; otherwise `NULL` | Ordinal code |
| `insomnia`, `fallsleepefficiency` | ≥0; otherwise `NULL` | Unresolved codes/values; not assumed to be durations or percentages |

Reject the whole row unless
`sleepduration = awake + remsleep + lightsleep + deepsleep` and all duration
bounds hold. `date` is the raw reference date, not an established sleep-start
or wake-up date. Sleep has no further aggregate layers.
[SQL](../etl/sql/sleep_tidy.sql).

## Evidence and row loss

Historical primary-source profiles support these decisions; counts describe
those snapshots, not current output or runtime assertions.

| Profile | Raw rows | Main evidence |
|---|---:|---|
| MyAir, 2026-08-24 | 54,451,379 | 12,613 invalid cells across 11,647 rows; no row lost solely to value cleaning. |
| SmartwatchLow, 2026-08-25 | 24,578,044 | Step/cal constant in 99.997%/99.998% of multi-reading five-minute buckets; pressure reversal follows firmware. |
| SmartwatchHigh, 2026-08-25 | 50,742,165 | Sleep code 0 occurs mainly at night; firmware availability differs. |
| Sleep, 2026-08-31 | 23,945 | All duration identities hold; 40 of 4,059 device/firmware/dates have revised payloads, supporting latest-upload selection. |

Routine summaries report source rows in the processed scope and the final
count of the entire tidy table; these are not directly comparable in increments.
Per-rule losses require focused validation: count missing keys, later/equal
copies, conflicting events, ambiguous minutes, mapping exclusions and unusable
rows separately. Counts at different stages are not interchangeable. No
participant-level rejection records are stored. Refresh logic and limitations
are in [architecture](architecture.md).
