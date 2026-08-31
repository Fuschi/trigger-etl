# `smartwatchlow_hourly` data specification

This table is derived only from `smartwatchlow_5min`. Its grain and primary
key are `(userId, hour_ts)`, where `hour_ts` begins a UTC hour.

Each hourly mean is an unweighted mean of available five-minute means; minima
and maxima combine their corresponding bucket extrema. Both contributing
five-minute bucket counts and underlying valid-minute counts are retained.
There is no minimum coverage requirement.

`step` and `cal` are deliberately not summed. Their device semantics remain
unresolved and the source profile indicates repeated values inside a bucket;
summing at this layer could therefore claim a false hourly total. The hourly
mean is a temporally balanced descriptive value pending sensor documentation.
Blood-pressure availability remains paired, and the existing tidy validity
boundaries are not broadened.

Mixed provenance is exposed through bucket counts. A scalar device or firmware
is retained only when all represented buckets are unmixed and agree.

`CALL etl_smartwatchlow_hourly();` performs a parameterless transactional full
rebuild. It refuses an empty source, checks expected and final row counts and
rolls back any failure. It must not overlap `etl_smartwatchlow_5min()`.
Incremental refresh remains deferred until a deletion-aware mechanism is
designed. Historical incompatible output requires an explicitly confirmed
replacement before deployment.
