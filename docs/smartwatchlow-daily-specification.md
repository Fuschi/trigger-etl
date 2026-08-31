# `smartwatchlow_daily` data specification

Shared cleaning, UTC and temporal-weighting rules are defined in
[`architecture.md`](architecture.md).

This table is derived only from `smartwatchlow_hourly`, with primary key
`(userId, date)` and UTC calendar-date semantics.

Daily means give identical temporal weight to every available hourly mean.
This includes `step` and `cal`: neither is summed because its sensor semantics
remain unresolved. Minima, maxima and hour, five-minute and minute counts are
retained for every measure. Blood-pressure availability remains paired.

`five_min_profile` and every `<measurement>_5min_profile` contain exactly 24
coverage counts ordered from UTC hour 00 through 23. Each value is between 0
and 12 and represents available five-minute buckets, not the measured value.
No minimum daily or hourly coverage is required.

Daily device and firmware are populated only when provenance is unambiguous
throughout the observed day. Ambiguous-hour and mixed-bucket counts are kept.

`CALL etl_smartwatchlow_daily();` performs a parameterless transactional full
replacement, rejects an empty hourly source and checks output cardinality. It
must not overlap `etl_smartwatchlow_hourly()`. Incremental refresh is not
implemented because this layer keeps no deletion-aware change log.
