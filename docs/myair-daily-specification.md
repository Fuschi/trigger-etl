# `myair_daily` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

`myair_daily` contains one row per `(userId, date)` and is derived only from
`myair_hourly`. Dates and clock hours are UTC.

For each of the 15 environmental measurements, the daily mean is the
unweighted mean of available hourly means; daily extrema combine hourly
extrema. `<measurement>_hours_n`, `<measurement>_5min_n` and
`<measurement>_minute_n` retain availability at all three temporal levels.
No coverage or exposure threshold is applied.

Every `<measurement>_5min_profile` is a JSON array of exactly 24 integers,
ordered from hour 00 through 23. An entry is the number of five-minute buckets
with that measurement during the corresponding hour; zero represents an
absent hour. `five_min_profile` provides the same coverage view for the stream
as a whole. These arrays describe coverage, not measurement values.

Scalar provenance is retained only for a completely unambiguous day; otherwise
the device or firmware is `NULL` and ambiguity counts remain visible.

`CALL etl_myair_daily();` is a transactional, parameterless full rebuild. Empty
source data and count mismatches preserve the previous valid output. It must
not overlap `etl_myair_hourly()`. Incremental refresh is not implemented
because this layer keeps no deletion-aware change log.
