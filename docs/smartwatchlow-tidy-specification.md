# `smartwatchlow_tidy` data specification

Shared cleaning, time and aggregation policy:
[`architecture.md`](architecture.md).

## Purpose

`smartwatchlow_tidy` contains one unambiguous low-frequency smartwatch
observation per participant and UTC minute. It retains the activity, blood
pressure and temperature-labelled measurements needed by the canonical
five-minute layer without retaining redundant calendar components.

```text
grain:       participant x UTC minute
primary key: (userId, minute_ts)
```

The raw `smartwatchlow` and `user_smartwatchlow` tables remain read only. The
tidy table is deliberately selective and can be rebuilt from raw data.

## Verified source schema

The primary schema was inspected on 2026-08-25 and exposes:

```text
smartwatchlow
  deviceId       VARCHAR(100) NULL
  firmware       VARCHAR(100) NULL
  event_ts       DATETIME NULL, stored generated
  created_at     TIMESTAMP NULL
  step           INT NOT NULL
  cal            INT NOT NULL
  bphigh         INT NOT NULL
  bplow          INT NOT NULL
  bodytemp       FLOAT NOT NULL
  skintemp       FLOAT NOT NULL

user_smartwatchlow
  userId         INT NOT NULL, primary key
  deviceId       VARCHAR(100) NULL
```

The generated `event_ts` is derived from the raw calendar components. The
procedure reads `created_at` with the MariaDB session set to UTC before storing
it in the tidy `DATETIME` column.

The mapping table is assumed not to contain validity intervals. A device
associated with more than one non-null participant is therefore excluded over
its complete history.

Aggregate mapping inspection on 2026-08-25 found 223 rows, 223 distinct
participants, 214 distinct non-empty devices and no missing device identifier.
Eight devices are ambiguous: seven are associated with two participants and
one with three participants, for 17 affected participant mappings. The
procedure excludes all raw history from those eight devices. Their identifiers
are deliberately not recorded in versioned documentation.

The same inspection classified the 24,584,879 raw rows then present in the
primary database as follows:

| Mapping result | Raw rows | Share |
|---|---:|---:|
| One participant | 22,753,384 | 92.55% |
| No mapping, across 10 devices | 1,539,892 | 6.26% |
| Ambiguous mapping, across 8 devices | 291,603 | 1.19% |
| Excluded by mapping in total | 1,831,495 | 7.45% |

These exclusions happen before exact-event and minute deduplication. The raw
database contained 6,835 more rows than the earlier downloaded snapshot
because ingestion continued after that snapshot was created.

The raw table has the composite index
`(deviceId, firmware, event_ts, created_at)`. It supports participant batches,
exact-event deduplication and complete-minute reconstruction. Because
`created_at` is the fourth column, it does not directly optimize the global
watermark maximum or the search for all newer uploads. Those operations may
still scan a substantial portion of the raw table. The mapping table has no
`deviceId` index, but it contains only 223 rows and the
procedure copies resolved mappings into an indexed temporary table.

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
| `step` | Step value reported for the containing five-minute period |
| `cal` | Non-negative calorie value on the recorded sensor scale for the containing five-minute period |
| `bphigh` | Greater positive member of the raw blood-pressure pair; presumed systolic mmHg |
| `bplow` | Lower positive member of the raw blood-pressure pair; presumed diastolic mmHg |
| `bodytemp` | Raw recorded value; meaning and unit unresolved |
| `skintemp` | Raw recorded value; meaning and unit unresolved |

The raw `year`, `month`, `day`, `hour`, `minute` and `second` columns are
omitted because they can be derived from `event_ts` or `minute_ts`.

## Deduplication and row exclusions

The transformation applies these rules in order:

1. Keep only devices associated with exactly one non-null participant in
   `user_smartwatchlow`.
2. Exclude rows missing `firmware`, `event_ts` or `created_at`; a missing
   `deviceId` cannot match the participant mapping.
3. For `(deviceId, firmware, event_ts)`, keep the earliest upload.
4. Collapse completely equal copies of that earliest upload.
5. Exclude the event if earliest copies disagree on any retained measurement.
6. Exclude a device/firmware-minute containing more than one event.
7. Clean every retained measurement independently, then exclude the row only
   when every measurement is `NULL`.
8. Exclude a participant-minute containing usable candidates from multiple
   devices or firmware versions.

The participant-minute exclusion is conservative: the procedure never chooses
arbitrarily between simultaneous devices, firmware versions or events.

## Measurement cleaning

An invalid measurement becomes `NULL`; it does not remove other valid values
from the same row.

| Measurement | Retained values | Reason |
|---|---:|---|
| `step` | values greater than or equal to `0` | No negative value or implausible upper sentinel was observed; the raw maximum of 925 is compatible with a very active five-minute interval |
| `cal` | values greater than or equal to `0` | No negative value was observed; the 352 values above 100 are suspicious but are retained because neither the unit nor a defensible upper threshold has been confirmed |
| `bphigh`, `bplow` | both raw values must be positive; store maximum then minimum | Zero is the missing-pair code and one firmware transmits the two positive fields in reverse order |
| `bodytemp` | any non-null recorded value | Meaning and unit are unresolved; no tidy-layer threshold is applied |
| `skintemp` | any non-null recorded value | Meaning and unit are unresolved; no tidy-layer threshold is applied |

`bodytemp` and `skintemp` are not assumed to represent body or skin
temperature. Zeros and values above 45 are retained for later interpretation.
The calorie unit is also unresolved; values above 100, including a maximum of
1697, remain on the recorded sensor scale.

## Step and calorie semantics

The raw snapshot provides strong empirical evidence that `step` and `cal` are
five-minute interval values repeated in minute-level records, not cumulative
counters:

- after exact-event deduplication, 2,483,494 five-minute device buckets contain
  more than one minute-level reading;
- `step` is constant in 2,483,429 of those buckets (99.997%);
- `cal` is constant in 2,483,437 of those buckets (99.998%);
- between consecutive five-minute buckets, increases and decreases occur at
  nearly equal frequencies for both measurements.

The tidy layer preserves the minute-level source observations. The canonical
five-minute layer represents each bucket with the mean, which is robust to the
rare within-bucket disagreement and does not multiply repeated values. It does
not sum the minute-level repetitions.

## Primary raw-data validation on 2026-08-25

The complete compressed raw dump was profiled locally in streaming mode. The
snapshot contained:

```text
raw rows:             24,578,044
distinct devices:            224
distinct firmware values:      2
event-time range:     2025-03-19 09:15:00 to 2026-12-31 23:59:00
ingestion-time range: 2025-04-01 14:05:57 to 2026-08-25 20:47:34
```

Every measurement, `deviceId`, `event_ts` and `created_at` was present,
numeric where applicable and parseable. Firmware was missing in 871 rows.
All `event_ts` seconds were zero and the separate calendar columns agreed with
`event_ts` in every row. The snapshot also contains 79,698 future-dated event
rows relative to the profiling date; they are retained because the shared date
window is an analysis rule, not a destructive tidy rule.

### Measurements with active cleaning rules

| Measurement | Raw minimum | P01 | Median | P99 | Raw maximum | Proposed values made `NULL` |
|---|---:|---:|---:|---:|---:|---:|
| `step` | 0 | 0 | 0 | 444 | 925 | 0 |
| `cal` | 0 | 0 | 0 | 23 | 1697 | 0; 352 values above 100 are flagged but retained |
| reordered `bphigh` | 107 | 112 | 120 | 128 | 137 | 5,804,783 zero pairs |
| reordered `bplow` | 67 | 73 | 79 | 89 | 93 | 5,804,783 zero pairs |

The two temperature-labelled fields are simultaneously zero in 13,431,372
rows. Values above 45 occur in 1,155 rows and reach 152 across the pair. All
these values are retained because their meaning and unit are unresolved.

The pressure-field reversal is entirely firmware-specific in this snapshot:

| Firmware | Positive pairs already ordered | Positive pairs reversed | Zero pairs |
|---|---:|---:|---:|
| `03.05.03` | 11,580,331 | 0 | 3,492,940 |
| `03.05.03-6549` | 0 | 7,192,930 | 2,310,972 |

This validates semantic reordering with `GREATEST` and `LEAST` instead of
trusting the raw field names.

### Raw duplicate structure

```text
raw rows:                                      24,578,044
distinct device/firmware/event groups:         14,660,925
later upload rows removed:                      9,916,582
equal earliest copies collapsed:                      537
conflicting earliest event groups:                      0
events retained before required-field checks:  14,660,925
historical unique-earliest result:              14,660,424
events recovered from equal copies:                    501
```

After excluding 871 missing-firmware events and six ambiguous device-minutes
spanning firmware versions, 14,660,042 device-minutes remain before participant
mapping in the downloaded snapshot. The later primary-database mapping
inspection, reported above, measures the corresponding mapping losses against
the continuously updated raw table.

## Full and incremental refresh

The procedure has no parameters:

```sql
CALL etl_smartwatchlow_tidy();
```

When `smartwatchlow_tidy` is empty, the call performs a full build. It processes
one participant at a time and commits after that participant is complete, so
the full history does not accumulate all InnoDB locks in one transaction. If
an ordinary SQL error occurs, the error handler rolls back the current batch
and truncates partial full output before returning the original error.

When the table is populated, the procedure uses
`MAX(smartwatchlow_tidy.created_at)` as its ingestion watermark. It finds raw
rows with a strictly greater `created_at`, identifies their affected
participant-minutes and rebuilds only those complete minutes from raw history.
The incremental delete and inserts remain in one transaction, so an SQL error
rolls back the complete incremental run.

Both modes freeze one raw maximum `created_at` at the start. No persistent
state, rejected-row table, shadow table or run-history table is created.
Scheduled executions must not overlap.

## Incremental limitations

- A raw row inserted later with exactly the current maximum `created_at` is not
  detected by the strict `>` comparison.
- Raw rows inserted later with a `created_at` older than the tidy maximum are
  not detected.
- If all newest raw rows are excluded or are later copies of older events, the
  tidy maximum may not advance and those rows are reconsidered on the next run.
- A change made only to `user_smartwatchlow` is not detectable from raw
  ingestion time.
- A full build is intentionally not one atomic transaction. An ordinary SQL
  error triggers cleanup, but a server crash or forced connection termination
  may prevent the handler from running. After such an interruption, empty the
  tidy table explicitly before retrying.
- Deliberately requesting another full refresh requires emptying the managed
  table before the next call.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible managed table.
  Replacing an older `smartwatchlow_tidy` schema is a separately confirmed
  database operation.

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

The returned summary provides routine source and output counts. The detailed
raw profile and mapping audit above provide focused rule-level evidence;
runtime privilege verification remains an operational installation check.
