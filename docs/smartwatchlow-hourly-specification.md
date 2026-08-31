# `smartwatchlow_hourly` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

This table is derived only from `smartwatchlow_5min`. Its grain and primary
key are `(userId, hour_ts)`, where `hour_ts` begins a UTC hour.

Each hourly mean is an unweighted mean of available five-minute means; minima
and maxima combine their corresponding bucket extrema. Both contributing
five-minute bucket counts and underlying valid-minute counts are retained.
There is no minimum coverage requirement.

`step` and `cal` are deliberately not summed. Their device semantics remain
unresolved and the source profile indicates repeated values inside a bucket;
summing at this layer could therefore claim a false hourly total. The hourly
mean is a temporally balanced descriptive value on the recorded sensor scale.
Blood-pressure availability remains paired. `bodytemp` and `skintemp` retain
their unresolved recorded scale without range filtering.

Mixed provenance is exposed through bucket counts. A scalar device or firmware
is retained only when all represented buckets are unmixed and agree.

`CALL etl_smartwatchlow_hourly();` performs a parameterless transactional full
rebuild. It refuses an empty source, checks expected and final row counts and
rolls back any failure. It must not overlap `etl_smartwatchlow_5min()`.
Incremental refresh is not implemented because this layer keeps no
deletion-aware change log. `CREATE TABLE IF NOT EXISTS` does not migrate an
incompatible existing schema; schema replacement is a separate installation
operation.
