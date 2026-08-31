# `smartwatchhigh_tidy` data specification

Shared cleaning, time and aggregation policy:
[`architecture.md`](architecture.md).

## Purpose

`smartwatchhigh_tidy` contains one unambiguous high-frequency smartwatch
observation per participant and UTC minute. It retains the cardiovascular,
respiratory and sleep-state measurements required by the canonical five-minute
layer without copying redundant calendar components.

```text
grain:       participant x UTC minute
primary key: (userId, minute_ts)
```

The raw `smartwatchhigh` and `user_smartwatchhigh` tables remain read only. The
tidy table is deliberately selective and can be rebuilt from raw data.

## Required source structure and interpretation

The SQL expects:

```text
smartwatchhigh
  deviceId, firmware, event_ts, created_at,
  heartrate, oxygens, breathrate, sleeprate

user_smartwatchhigh
  deviceId, userId
```

The definition requires `event_ts` to be `DATETIME`, `created_at` to be
`TIMESTAMP` and the measurements to be numeric. It reads `created_at` with the
session set to UTC before storing it as tidy `DATETIME(6)`. The event time has
no timezone offset, so the ETL explicitly interprets it as UTC.

The mapping table is assumed not to contain validity intervals. A device
associated with more than one non-null participant is therefore excluded over
its complete history.

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
| `heartrate` | Positive heart rate in beats per minute |
| `oxygens` | Oxygen saturation from 1 through 100 percent |
| `breathrate` | Breathing rate from 1 through 100 breaths per minute |
| `sleeprate` | Raw categorical sleep-state code from 0 through 4; labels remain unresolved |

The raw `year`, `month`, `day`, `hour`, `minute` and `second` columns are
omitted because they can be derived from `event_ts` or `minute_ts`.

## Deduplication and row exclusions

The transformation applies these rules in order:

1. Keep only devices associated with exactly one non-null participant in
   `user_smartwatchhigh`.
2. Exclude rows missing `firmware`, `event_ts` or `created_at`; a missing
   `deviceId` cannot match the participant mapping.
3. For `(deviceId, firmware, event_ts)`, keep the earliest upload.
4. Collapse completely equal copies of that earliest upload.
5. Exclude the event if earliest copies disagree on a retained measurement.
6. Exclude a device/firmware-minute containing more than one event.
7. Clean every measurement independently, then exclude the row when all four
   measurements are `NULL`.
8. Exclude a participant-minute containing usable candidates from multiple
   devices or firmware versions.

The participant-minute exclusion is conservative: the procedure never chooses
arbitrarily between simultaneous devices, firmware versions or events.

## Measurement cleaning

An invalid or unavailable measurement becomes `NULL`; it does not remove other
usable measurements from the same row.

| Measurement | Retained values | Observed technical missing or error codes |
|---|---:|---|
| `heartrate` | values greater than `0` | `0` |
| `oxygens` | `1` through `100` | `0` |
| `breathrate` | `1` through `100` | `-1`, `0`, `255` |
| `sleeprate` | integer codes `0` through `4` | `-1` |

The first three rules remove explicit device codes rather than inventing
narrower clinical thresholds. No upper
heart-rate filter is applied: all positive raw values, from 41 through 203 bpm,
are retained.

The complete raw profile does not support converting `sleeprate = 0` to
`NULL`: it is concentrated at night and frequently transitions to codes 1 and
2. It may represent an awake state, but the available source metadata do not
confirm that label.
Tidy therefore retains codes 0 through 4 without assigning semantic stage
names; only `-1` is treated as unavailable. Code 3 was absent from the snapshot
but remains allowed by the observed code family.

## Complete raw-data validation on 2026-08-25

The compressed raw dump was downloaded directly and profiled in full:

```text
raw rows:             50,742,165
distinct devices:            224
firmware values:               2 plus missing
event-time range:     2025-03-19 09:10:00 to 2026-12-31 23:59:00
ingestion-time range: 2025-04-01 11:26:54 to 2026-08-25 20:46:14
```

Every measurement, `deviceId`, `event_ts` and `created_at` was present and
parseable. Firmware was missing in 4,484 rows. All measurements were integers,
all event seconds were zero and the six separate calendar columns agreed with
`event_ts` in every row. The snapshot contains 85,458 future-dated event rows
relative to the profiling date; they remain in tidy because the project date
window belongs to analyses, not destructive ETL.

### Raw measurement distributions

| Measurement | Raw minimum | P01 | Median | P99 | Raw maximum | Values made `NULL` |
|---|---:|---:|---:|---:|---:|---:|
| `heartrate` | 0 | 0 | 66 | 110 | 203 | 12,989,244 zeros |
| `oxygens` | 0 | 0 | 0 | 98 | 99 | 41,397,603 zeros |
| `breathrate` | -1 | -1 | -1 | 255 | 255 | 34,571,182 values of -1; 526,471 zeros; 3,605,030 values of 255 |
| `sleeprate` | -1 | -1 | -1 | 2 | 4 | 45,115,862 values of -1 |

The retained positive ranges are 41–203 bpm for heart rate, 83–99 percent for
oxygen saturation and 2–50 breaths per minute for breathing rate. Retained
sleep-state codes contain 1,310,623 code-0 readings, 2,791,731 code-1 readings,
1,480,477 code-2 readings and 43,472 code-4 readings.

Counts produced under a rule that treated sleep code 0 as missing are obsolete
and are not used by this definition. Routine output follows the retained
0-through-4 rule.

### Firmware-specific availability

Measurement availability differs structurally between firmware versions:

- `03.05.03` contributes 16,166,499 rows. Its `sleeprate` is always `-1`, while
  valid breathing-rate measurements are present in 12,039,482 rows.
- `03.05.03-6549` contributes 34,571,182 rows. Its `breathrate` is always `-1`,
  while it contributes 1,306,188 code-0 readings and 4,315,631 readings with
  codes 1 through 4.
- the 4,484 rows without firmware are excluded before deduplication.

The two firmware versions therefore expose nearly complementary measurements:
the first provides breathing rate but no sleep state, while the second provides
sleep state but no breathing rate. This is technical availability, not a
physiological change. The procedure cleans every measurement independently and
never removes a row merely because its firmware does not provide one of the
other variables.

### Zero-code interpretation

`breathrate = 0` occurs in 526,471 raw rows. Its occurrence is nearly uniform
across the day, and device sequences can remain zero for more than 23
consecutive days. It is therefore treated as unavailable rather than as an
apnoea marker.

`sleeprate = 0` occurs in 1,310,623 raw rows; 98.6 percent of the non-missing
firmware readings occur between 21:00 and 08:59. After collapsing repeated
device/firmware timestamps, code 0 commonly borders codes 1 and 2 and appears
in sequences of up to 125 minutes. These patterns support retaining it as a
real categorical state, potentially awake, but do not justify assigning that
clinical label without the device codebook.

### Raw duplicate structure

```text
raw rows:                                           50,742,165
rows with required technical fields:               50,737,681
distinct device/firmware/event groups:              23,736,993
later upload rows removed:                          26,997,973
equal earliest copies collapsed:                         2,715
conflicting earliest event groups:                           0
events retained by the new exact-event rule:        23,736,993
historical unique-earliest result:                  23,734,367
events recovered from equal earliest copies:            2,626
cross-firmware ambiguous device-minutes:                    30
events removed from those ambiguous minutes:               60
device-minutes before mapping and value exclusion:  23,736,933
```

No device/firmware-minute contained multiple distinct events after exact-event
deduplication. The only minute ambiguity observed was the 30 minutes containing
one candidate from each firmware version.

## Five-minute implications

For buckets containing at least two valid values, the complete raw profile
shows that:

- heart rate varies within 98.89 percent of buckets;
- oxygen saturation varies within 53.47 percent of buckets;
- breathing rate varies within 99.75 percent of buckets;

The canonical five-minute layer therefore retains arithmetic mean, minimum,
maximum and reading counts for the three continuous measurements. `sleeprate`
is categorical and is represented by separate counts for codes 0 through 4,
not by an arithmetic mean. No minimum coverage threshold belongs in the core
ETL.

## Full and incremental refresh

The procedure has no parameters:

```sql
CALL etl_smartwatchhigh_tidy();
```

When `smartwatchhigh_tidy` is empty, the procedure performs a full build. It
processes one participant at a time and commits after that participant is
complete, bounding InnoDB lock usage. If an ordinary SQL error occurs, the
handler rolls back the current participant and truncates partial full output
before returning the original error.

When the table is populated, the procedure uses
`MAX(smartwatchhigh_tidy.created_at)` as its ingestion watermark. It finds raw
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
- A change made only to `user_smartwatchhigh` is not detectable from raw
  ingestion time.
- A full build is intentionally not one atomic transaction. An ordinary SQL
  error triggers cleanup, but a server crash or forced connection termination
  may leave partial output. Empty the tidy table explicitly before retrying.
- Deliberately requesting another full refresh requires emptying the managed
  table before the next call.
- `CREATE TABLE IF NOT EXISTS` does not migrate an incompatible managed table.
  Replacing an older `smartwatchhigh_tidy` schema is a separately confirmed
  database operation.

## Returned summary

Every successful call returns one non-persistent row containing:

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

The complete raw profile above supports the measurement rules. Mapping
cardinality, mapping-related losses and effective privileges are checked
operationally against the selected database because they can change
independently of this versioned definition.
