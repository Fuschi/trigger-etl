# `myair_hourly` data specification

`myair_hourly` contains one row per `(userId, hour_ts)` and is derived only
from `myair_5min`. `hour_ts` is the beginning of the UTC hour.

For every retained environmental measurement, the hourly mean is the
unweighted mean of available five-minute means. The minimum and maximum are
the extrema of the corresponding bucket extrema. `<measurement>_5min_n`
counts contributing buckets and `<measurement>_minute_n` sums their underlying
valid-minute counts. Thus missingness remains measurable without giving dense
buckets greater influence. No coverage or exposure threshold is applied.

`observed_5min_n` is between 1 and 12 and `observed_minute_n` between 1 and
60. Provenance follows the canonical participant policy: mixed-bucket counts
are retained, while scalar device and firmware values are populated only when
the entire hour is unambiguous. Exact distinct identifiers hidden inside an
already mixed source bucket are not reconstructed or guessed.

`CALL etl_myair_hourly();` performs a full transactional replacement from one
consistent source snapshot. Empty source data and row-count mismatches fail
the run without erasing the preceding valid output. Incremental processing is
deferred until this definition is operationally validated and a deletion-aware
refresh mechanism exists. The procedure must not overlap `etl_myair_5min()`.

An incompatible historical table requires an explicitly confirmed replacement
before first deployment.
