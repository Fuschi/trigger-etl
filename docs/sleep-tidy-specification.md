# `sleep_tidy` data specification

## Purpose

`sleep_tidy` contains one unambiguous nightly summary per participant and raw
reference date. Sleep is already reported as a daily/nightly summary, so this
stream does not create minute or five-minute rows.

```text
grain:       participant x raw reference date
primary key: (userId, date)
```

The raw `sleep` and `user_sleep` tables remain read only. The tidy table is a
small curated result that can always be rebuilt from raw data.

## Reference-date semantics

The raw source supplies `year`, `month` and `day`, plus clock components that
are zero in 23,935 of 23,945 downloaded rows. The source does not supply a
sleep-start or sleep-end timestamp, and no device codebook has yet established
what the calendar date denotes.

Tidy therefore constructs `date` from the raw calendar fields and calls it the
**raw reference date**. It must not be interpreted as either the sleep-start
date or wake-up date without external documentation. The raw clock components
are omitted because they do not provide a reliable nightly timestamp.

`created_at` is an ingestion timestamp, not a sleep-event timestamp. It is
expected to be a raw MariaDB `TIMESTAMP`; the procedure reads it in UTC and
stores it as tidy `DATETIME(6)`.

## Source assumptions to verify

The SQL expects:

```text
sleep
  year, month, day, hour, minute, second,
  sleepduration, awake, insomnia, remsleep, lightsleep, deepsleep,
  sleepquality, fallsleepefficiency,
  firmware, deviceId, created_at

user_sleep
  deviceId, userId
```

The complete raw snapshot confirms the column names and observed contents.
Before deployment, the primary database must still confirm MariaDB column
types, indexes, participant-mapping cardinality and mapping-related row loss.

The mapping table is assumed not to contain validity intervals. A device
associated with more than one non-null participant is therefore excluded over
its complete history.

## Output columns

| Column | Meaning |
|---|---|
| `userId` | Pseudonymous participant identifier |
| `date` | Raw nightly reference date; start/end interpretation unresolved |
| `created_at` | Ingestion time of the selected final summary, normalized to UTC |
| `deviceId` | Source-device provenance |
| `firmware` | Source-firmware provenance |
| `sleepduration` | Total recorded sleep summary duration, in apparent minutes |
| `awake` | Awake component, in apparent minutes; zero is retained |
| `insomnia` | Non-negative raw code/value; semantics and unit unresolved |
| `remsleep` | REM component, in apparent minutes; zero is retained |
| `lightsleep` | Light-sleep component, in apparent minutes; zero is retained |
| `deepsleep` | Deep-sleep component, in apparent minutes; zero is retained |
| `sleepquality` | Raw ordinal quality code from 1 through 5 |
| `fallsleepefficiency` | Non-negative raw value; semantics and unit unresolved |

The four duration components and total are stored as integers because every
value in the complete snapshot is integral. `insomnia` and
`fallsleepefficiency` are deliberately not relabelled as durations or
percentages without a codebook.

## Deduplication and row exclusions

The transformation applies these rules in order:

1. Construct a valid SQL `DATE` from raw `year`, `month` and `day`.
2. Keep only non-blank `deviceId` and `firmware` values and non-null
   `created_at` values.
3. Keep only devices associated with exactly one non-null participant in
   `user_sleep`.
4. Within `(deviceId, firmware, date)`, select the greatest `created_at` not
   later than the frozen cutoff for the run. This represents the last visible
   version of that nightly summary.
5. Collapse completely equal copies at that greatest `created_at`.
6. Exclude the device/firmware/date when equal-time final copies disagree on a
   retained raw value.
7. Exclude rows whose total or component durations are negative, exceed 1,440
   minutes, or fail the exact identity
   `sleepduration = awake + remsleep + lightsleep + deepsleep`.
8. Convert an invalid `sleepquality` to `NULL`; retain only codes 1 through 5.
9. Convert negative `insomnia` or `fallsleepefficiency` values to `NULL`.
10. Exclude a participant/date containing more than one remaining device or
    firmware candidate rather than selecting one arbitrarily.

The latest upload is used instead of the historical earliest-upload rule
because raw rows behave as successive versions of one nightly summary. Among
4,059 device/firmware/date keys, 40 have two distinct payloads and the last
payload differs from the first in all 40. Total duration changes in 38: it
increases in 24 and decreases in 14. The ETL therefore treats the latest
visible version as the deterministic final correction, not as another night
to aggregate.

The row-level duration rule is conservative but destructive. It is based on a
physical 24-hour bound and on an exact structural identity observed in every
one of the 23,945 raw rows. The rule removes the entire summary because an
internally inconsistent nightly composition cannot be repaired without
inventing values. Invalid ancillary codes affect only their own output value.

## Complete raw-data validation on 2026-08-31

The compressed `sleep` dump was downloaded directly, passed `gzip -t` and was
profiled in full outside the repository:

```text
raw rows:                    23,945
distinct devices:               81
firmware values:                  1
reference-date range:    2025-04-18 through 2026-08-30
ingestion-time range:    2025-04-18 22:39:38 through 2026-08-30 19:48:09
missing raw values:               0
invalid constructed dates:       0
```

The sole observed firmware is `03.05.03-6549`. All values are present and
integer-valued. These observations describe the snapshot; they are not used as
a filter on future firmware versions.

### Duration distributions

The snapshot strongly supports minutes as the duration unit. Every row obeys
`sleepduration = awake + remsleep + lightsleep + deepsleep` exactly.

| Measurement | Minimum | P01 | Median | P99 | Maximum | Raw zeros |
|---|---:|---:|---:|---:|---:|---:|
| `sleepduration` | 20 | 26 | 430 | 640 | 758 | 0 |
| `awake` | 0 | 0 | 0 | 32 | 80 | 18,741 |
| `remsleep` | 0 | 8 | 97 | 218 | 241 | 8 |
| `lightsleep` | 10 | 15 | 212 | 344 | 398 | 0 |
| `deepsleep` | 0 | 3 | 101 | 183 | 335 | 14 |

Zeros are retained: they are valid component observations and do not mean a
missing nightly record.

### Ancillary variables

`sleepquality` contains only integer codes 1 through 5. Raw counts are 9, 314,
6,506, 16,999 and 117 respectively, supporting an ordinal code rather than a
percentage.

`insomnia` contains 23,940 zeros and five values equal to 2. Adding it to the
four duration components breaks the otherwise exact duration identity, so it
is not treated as a duration. After nightly deduplication, only one code-2
summary remains.

`fallsleepefficiency` ranges from 0 through 290, with 150 raw values above 100.
It therefore cannot safely be treated as a percentage. Its distribution and
negative association with quality are compatible with a sleep-onset latency,
but that interpretation is not sufficiently established to rename it or add a
scientific cutoff.

### Raw duplicate structure

```text
raw rows:                                      23,945
device/firmware/reference-date keys:            4,059
keys with repeated uploads:                     3,253
rows after choosing the latest upload time:     4,064
equal latest copies collapsed:                      5
conflicting equal-time final payloads:               0
device/firmware/date summaries before mapping:  4,059
```

Most repeated uploads have identical values. Forty keys contain a later,
different payload; no key contains more than two distinct payloads. Uploads
may arrive long after their reference date, confirming that ingestion time
must not be used as the night date.

## Full and incremental refresh

The procedure has no parameters:

```sql
CALL etl_sleep_tidy();
```

When `sleep_tidy` is empty, it performs a full build using all raw rows visible
at one frozen maximum `created_at`. The small nightly output is replaced in one
transaction.

When `sleep_tidy` is populated, the procedure uses
`MAX(sleep_tidy.created_at)` as its ingestion watermark. Raw uploads with a
strictly greater `created_at` identify affected participant/reference-date
keys. The procedure deletes those tidy keys and rebuilds them from their
complete raw history up to the same frozen cutoff. A later corrected summary
therefore replaces the prior version. The delete and insert are one
transaction, so an SQL error rolls back the entire run.

No parameter, persistent state table, rejected-row table, shadow table or
run-history table is created. Scheduled executions must not overlap.

## Incremental limitations

- A raw row inserted later with exactly the current tidy maximum `created_at`
  is not detected by the strict `>` comparison.
- A raw row inserted later with a `created_at` older than the tidy maximum is
  not detected.
- If the newest upload is excluded, the tidy maximum may not advance and it
  will be reconsidered on the next run.
- Changes made only to `user_sleep` are not detectable from raw ingestion time.
- Reassignments cannot be modelled because the mapping has no validity dates;
  whole-device ambiguity is excluded conservatively.
- Deliberately requesting another full refresh requires emptying the managed
  table before the next call.
- The historical `sleep_tidy` schema has a different primary key and must not
  merely be truncated before first deployment of this definition.

## Returned summary

Every successful call returns one non-persistent row containing:

```text
run_mode
started_at
finished_at
previous_created_at
raw_max_created_at
affected_nights
source_rows
deleted_tidy_rows
inserted_tidy_rows
total_tidy_rows
```

The complete per-rule row-loss profile is a focused validation result rather
than a persistent rejection log. It must be recalculated after primary mapping
validation and before deployment is considered complete.
