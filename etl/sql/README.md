# SQL conventions

This directory contains the SQL objects implementing the TRIGGER ETL pipeline.

## Naming

| Pattern | Purpose |
|---|---|
| `vw_*.sql` | reusable database views |
| `etl_*_tidy.sql` | cleaned and deduplicated base tables |
| `etl_*_5min.sql` | fixed 5-minute materialized aggregations |
| `etl_*_hourly.sql` | hourly materialized aggregations |
| `etl_*_daily.sql` | daily materialized aggregations |

Each ETL file defines the target table schema and a stored procedure named after that table.

Example:

```text
file:      etl_myair_hourly.sql
procedure: etl_myair_hourly()
table:     myair_hourly
```

## Tidy layer

The tidy layer performs stream-specific cleaning without temporal aggregation. Time-series streams generally apply:

- second-level deduplication using the earliest uniquely identified upload;
- minute-level deduplication;
- validation of one-to-one device-to-user bindings;
- assignment to fixed 5-minute buckets;
- measurement-specific validity checks.

Raw tables are read only.

## Aggregation semantics

### Five-minute

One row is produced for each device, firmware and fixed 5-minute interval. Available raw readings are summarized using measurement-specific statistics and counts.

### Hourly

Hourly tables are built from 5-minute tables. Every available 5-minute bucket receives equal temporal weight, regardless of the number of raw readings inside it.

### Daily

Daily tables are built from hourly tables. Every available hourly mean receives equal weight in the corresponding daily mean.

Daily tables retain scalar coverage summaries and fixed JSON arrays of 24 elements. Array position `0` represents hour `00`, while position `23` represents hour `23`. Each value is the number of valid 5-minute buckets represented in that hour, from `0` to `12`.

```json
[0, 0, 0, 0, 0, 0, 4, 8, 12, 12, 9, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
```

Common coverage fields include:

| Field | Meaning |
|---|---|
| `*_raw_n` | valid raw readings represented |
| `*_5min_n` | valid 5-minute buckets represented |
| `*_hours_n` | hourly values contributing to the daily statistic |
| `*_5min_per_hour_mean` | average valid 5-minute buckets per contributing hour |
| `*_complete_hours_n` | contributing hours containing all 12 buckets |
| `*_5min_profile` | fixed 24-hour JSON coverage profile |

No minimum coverage threshold is enforced in SQL.

## Special cases

- GPS coordinates are retained independently of accuracy availability.
- Sleep data are natively daily/nightly and have no 5-minute or hourly layer.
- Sleep stage is categorical and is summarized through class counts.
- Steps and calories retain multiple summaries because cumulative or incremental semantics are not assumed.
