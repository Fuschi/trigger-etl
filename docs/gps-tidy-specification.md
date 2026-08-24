# `gps_tidy` data specification

## Purpose

`gps_tidy` contains one unambiguous, technically valid GPS reading per
participant and UTC minute.

```text
grain:       participant x UTC minute
primary key: (userId, minute_ts)
```

Raw tables remain untouched. The tidy table is deliberately selective and can
always be rebuilt from raw data.

## Source assumptions to verify

The SQL expects:

```text
gps
  deviceId, firmware, event_ts, created_at,
  longitude, latitude, accuracy

user_gps
  deviceId, userId
```

Read-only schema inspection confirmed that `gps.event_ts` is a generated
`DATETIME` and `gps.created_at` is a `TIMESTAMP`. The procedure therefore reads
`created_at` with the MariaDB session set to UTC before storing it in the tidy
`DATETIME` column. The timezone represented by the components used to generate
`event_ts` must still be verified, as must the immutability of `created_at` and
whether device assignments contain validity dates or change timestamps.

## Output columns

| Column | Meaning |
|---|---|
| `userId` | Participant identifier |
| `minute_ts` | Beginning of the UTC minute |
| `bucket_5min` | Beginning of the containing UTC five-minute bucket |
| `event_ts` | Original event timestamp |
| `created_at` | Original ingestion timestamp normalized to UTC; incremental reference |
| `deviceId` | Device provenance |
| `firmware` | Firmware provenance |
| `longitude` | Longitude in decimal degrees |
| `latitude` | Latitude in decimal degrees |
| `accuracy` | Horizontal accuracy in metres, when available |

## Cleaning rules

The single SQL transformation applies these rules in order:

1. Exclude rows missing `deviceId`, `firmware`, `event_ts` or `created_at`.
2. For `(deviceId, firmware, event_ts)`, keep the earliest upload.
3. Collapse completely equal copies of that earliest upload.
4. Exclude the event if earliest copies disagree on GPS values.
5. Exclude a device/firmware-minute containing more than one event.
6. Keep only complete coordinates within longitude `[-180, 180]` and latitude
   `[-90, 90]`.
7. Convert null, zero or negative accuracy to `NULL`; retain the position.
8. Keep only devices associated with exactly one participant in `user_gps`.
9. Exclude a participant-minute containing candidates from multiple devices or
   firmware versions.

There is no geographic, speed, study-area, date-window or maximum-accuracy
filter. Those decisions require additional scientific justification.

## Database objects

The implementation deliberately uses only:

```text
gps_tidy
etl_gps_tidy()
```

No separate watermark or state table is created. Scheduled executions must not
overlap.

## Full refresh

The first call is:

```sql
CALL etl_gps_tidy();
```

When `gps_tidy` is empty, `MAX(gps_tidy.created_at)` is `NULL` and the
procedure automatically selects a full refresh.

The procedure:

1. starts one InnoDB transaction;
2. reads `MAX(gps.created_at)` as the raw upper boundary;
3. identifies every GPS event date visible at that boundary;
4. deletes the current `gps_tidy` rows with transactional `DELETE`;
5. rebuilds all dates using one `INSERT ... WITH ... SELECT` statement;
6. commits the replacement.

Because `DELETE` and `INSERT` share one transaction, a failure rolls both back.
This simpler approach is appropriate while GPS remains a small table.

## Incremental refresh

Run the same call nightly:

```sql
CALL etl_gps_tidy();
```

When `gps_tidy` contains rows, its maximum `created_at` is not `NULL` and the
procedure automatically selects an incremental refresh.

The procedure:

1. reads `MAX(created_at)` from `gps_tidy`;
2. finds every raw row whose `created_at` is greater than that value;
3. collects the event dates touched by those rows;
4. deletes tidy rows for those dates;
5. rebuilds the complete affected dates from raw GPS.

There is no fixed lookback and no state update. Rebuilding days rather than
inserting only new rows ensures that a late upload can invalidate an existing
minute when it introduces a conflict.

## Limitations

- The incremental comparison assumes that every raw row sharing the current
  maximum `created_at` is already present. A row inserted later with exactly
  the same timestamp would not satisfy the strict `>` comparison.
- If the newest raw rows are all excluded by tidy rules, the tidy maximum does
  not advance and those raw rows are reconsidered on the next run. This repeats
  work but does not silently accept them.
- Rows inserted later with a `created_at` older than the tidy maximum are not
  detected.
- A change made only to `user_gps` is not detectable from GPS ingestion time.
- With no mode parameter, a deliberate later full refresh requires emptying
  the managed table before the next call. That database-changing operation
  must be reviewed and explicitly confirmed.
- The initial database setup assumes `gps_tidy` either does not exist or
  already has the documented schema. Replacing an older incompatible managed
  table must be a separately confirmed action.

## Returned summary

Every call returns one row containing:

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

No row-level rejection log or persistent execution history is created.
