# `gps_daily` data specification

`gps_daily` is derived only from `gps_hourly`. Its grain and primary key are
`(userId, date)`, where `date` is the UTC calendar date.

Daily coordinate and accuracy means give equal weight to every hour containing
the relevant value. They are not weighted by five-minute or minute density.
Minima and maxima combine hourly extrema. Position coverage equals the general
GPS coverage because every retained GPS bucket contains coordinates; accuracy
keeps separate availability counts.

`five_min_profile`, `position_5min_profile` and `accuracy_5min_profile` are JSON
arrays containing exactly 24 integers ordered from hour 00 through 23. Each
entry is the number of valid five-minute buckets in that UTC clock hour, from
0 through 12. They are coverage profiles, not coordinate or accuracy values.
The table also retains daily hour, five-minute and underlying minute counts.
No minimum coverage rule is applied.

Ambiguous hourly provenance is counted. A daily scalar device or firmware is
retained only when every observed hour is unambiguous and all values agree.

`CALL etl_gps_daily();` performs a parameterless transactional full rebuild.
It refuses an empty source, verifies expected participant-day counts and rolls
back any error. It must not overlap `etl_gps_hourly()`. Incremental refresh is
deferred until a deletion-aware mechanism exists. Replacing an incompatible
historical table requires separate explicit confirmation before deployment.
