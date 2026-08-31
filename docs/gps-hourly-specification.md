# `gps_hourly` data specification

## Purpose and grain

`gps_hourly` is derived only from `gps_5min` and has one row per participant
and UTC hour. Its enforced key is `(userId, hour_ts)`.

Each available five-minute bucket receives equal weight in `longitude_mean`,
`latitude_mean` and `accuracy_mean`. Consequently, a bucket containing five
observed minutes does not receive five times the weight of a bucket containing
one. Minima and maxima are the extrema of the five-minute extrema.

## Coverage and provenance

`observed_5min_n` is between 1 and 12. `observed_minute_n` is the sum of the
underlying five-minute minute counts and is between 1 and 60. Accuracy retains
both the number of contributing buckets (`accuracy_5min_n`) and underlying
minutes (`accuracy_minute_n`). No minimum coverage is required.

Exact distinct device counts cannot be reconstructed after a mixed five-minute
bucket has intentionally hidden its scalar device. The hourly layer therefore
does not invent such counts. It stores the number of already mixed buckets and
retains `deviceId` or `firmware` only when every represented bucket is
unmixed and all scalar values agree.

## Refresh model

`CALL etl_gps_hourly();` performs a parameterless transactional full rebuild.
It fails before deletion when `gps_5min` is empty and rolls back on any SQL
error. This deletion-aware first implementation precedes incremental design.
The procedure returns UTC timing and source, expected, deleted, inserted and
final row counts. It must not overlap the `gps_5min` refresh.

An incompatible historical table must be replaced explicitly before first
deployment; `CREATE TABLE IF NOT EXISTS` does not migrate it.
