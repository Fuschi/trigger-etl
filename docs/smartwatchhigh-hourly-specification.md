# `smartwatchhigh_hourly` data specification

`smartwatchhigh_hourly` is derived only from `smartwatchhigh_5min`. One row
represents `(userId, hour_ts)`, with an hour beginning in UTC.

Heart rate, oxygen saturation and breathing rate use equal-weight means of
available five-minute means. Their extrema combine bucket extrema. Both
contributing bucket and underlying minute counts are retained. This preserves
the known firmware-dependent availability of breathing rate and sleep state;
absence is not interpreted as a physiological value.

`sleeprate` remains categorical. The hourly table sums the neutral raw-code
counts 0 through 4 and never calculates a numerical mean or chooses a dominant
state. Code zero remains a valid observed category. `sleeprate_5min_n` counts
buckets containing a code and `sleeprate_minute_n` equals the sum of all code
counts. The physiological meaning of each code remains unresolved.

No coverage or clinical filter is applied. Provenance is scalar only when the
complete hour is unambiguous; counts expose already mixed source buckets.

`CALL etl_smartwatchhigh_hourly();` performs a parameterless transactional
full rebuild. Empty source data or row-count mismatch fails without replacing
the preceding valid output. It must not overlap
`etl_smartwatchhigh_5min()`. Incremental design remains deferred until a
deletion-aware refresh mechanism is available. An incompatible historical
table requires explicitly confirmed replacement before deployment.
