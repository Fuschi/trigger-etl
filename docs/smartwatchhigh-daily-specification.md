# `smartwatchhigh_daily` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

`smartwatchhigh_daily` has one row per `(userId, date)` and reads only
`smartwatchhigh_hourly`. The date and all 24 profile positions use UTC.

Heart rate, oxygen saturation and breathing rate use equal-weight means of
available hourly means, plus daily extrema and availability at hour,
five-minute and minute level. Firmware-dependent absence remains missing data,
not physiology.

The general and measurement-specific `*_5min_profile` columns are JSON arrays
of exactly 24 five-minute coverage counts, ordered from hour 00 through 23.
Zero represents no valid value in that hour. `sleeprate` remains categorical:
codes 0 through 4 are summed separately, while its profile reports coverage
and never averages or selects a dominant code.

No coverage or clinical threshold is applied. Provenance is scalar only when
the whole observed day is unambiguous.

`CALL etl_smartwatchhigh_daily();` is a parameterless transactional full
rebuild with empty-source protection and cardinality checks. It must not overlap
`etl_smartwatchhigh_hourly()`. Incremental refresh is not implemented because
this layer keeps no deletion-aware change log.
