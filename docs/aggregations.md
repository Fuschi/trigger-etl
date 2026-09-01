# Aggregate data specification

This document describes the shared five-minute, hourly and daily layers for
GPS, MyAir, SmartwatchLow and SmartwatchHigh. Cleaning, deduplication and raw
data distributions remain in the stream-specific tidy specifications.

## Flow and keys

```text
<stream>_tidy → <stream>_5min → <stream>_hourly → <stream>_daily
```

| Layer | Source | Grain and primary key |
|---|---|---|
| Five-minute | Corresponding tidy table | `(userId, bucket_5min)` |
| Hourly | Corresponding five-minute table | `(userId, hour_ts)` |
| Daily | Corresponding hourly table | `(userId, date)` |

All boundaries are UTC. Sleep is excluded because its raw source is already a
nightly summary and ends at `sleep_tidy`.

Five minutes are the shared interval chosen for the four sensor streams: they
are the minimum common interval across the devices. This is a project
convention, not a claim that five minutes are statistically optimal.

## Temporal aggregation

The hierarchy uses equal temporal-unit weighting:

```text
tidy → five-minute: mean of available participant-minutes
five-minute → hour: mean of available five-minute means
hour → day: mean of available hourly means
```

A five-minute bucket formed from one observed minute therefore has the same
weight in an hourly mean as one formed from five observed minutes. Likewise,
an hour formed from one bucket has the same weight in a daily mean as one
formed from twelve buckets. This is an explicit simplification. Coverage
columns retain the number of contributing minutes, buckets and hours so that
analyses can evaluate or replace this weighting.

At every aggregate level, each continuous measurement always retains its mean,
minimum and maximum, together with its availability count. Means ignore
`NULL`; hourly and daily minima and maxima propagate the extrema observed in
the lower layer. No minimum coverage threshold is applied.

## Coverage

The general coverage columns are:

| Layer | Coverage |
|---|---|
| Five-minute | `observed_minute_n`, between 1 and 5 |
| Hourly | `observed_5min_n`, between 1 and 12, plus `observed_minute_n` |
| Daily | `hours_n`, `five_min_n` and `minute_n` |

Measurement-specific counts distinguish general stream presence from actual
availability of one variable. At five minutes they count valid minutes; at the
hourly and daily levels they retain contributing buckets and underlying time
units.

Daily `five_min_profile` and measurement-specific `*_5min_profile` columns are
JSON arrays of exactly 24 integers ordered from UTC hour 00 through 23. Each
entry is a five-minute coverage count from 0 through 12, not a measurement
value.

## Provenance

`deviceId` and `firmware` are provenance, not aggregation keys. Each layer
retains their distinct or ambiguity counts. A scalar identifier is populated
only when the complete period is unambiguous; otherwise it is `NULL`. The ETL
does not guess identifiers hidden by an already mixed lower-level period.

## Stream-specific rules

| Stream | Aggregated values | Specific policy |
|---|---|---|
| GPS | Longitude, latitude and accuracy | Mean, minimum and maximum are retained. Coordinates are descriptive positions, not distance or trajectory estimates. Accuracy is optional and has separate availability counts. |
| MyAir | 15 environmental measurements retained by tidy | Mean, minimum and maximum are retained independently for every measurement. No exposure category, Humidex or scientific threshold is added. |
| SmartwatchLow | Step, calories, pressure pair and temperature-labelled fields | Mean, minimum and maximum are retained. Step and calories are averaged, never summed, because raw values are normally repeated within five-minute intervals and their counter semantics are unresolved. Pressure availability remains paired. Temperature-labelled fields retain their unresolved raw scale. |
| SmartwatchHigh | Heart rate, oxygen saturation, breathing rate and sleep-state codes | Mean, minimum and maximum are retained for the first three continuous measurements. `sleeprate` is categorical: codes 0 through 4 are counted separately and are never averaged or assigned stage names. Firmware-dependent absence remains missing data, not physiology. |

The aggregate layers do not add cleaning rules. Every tidy row contributes to
its participant-time bucket, while each measurement contributes only when its
tidy value is non-null.
