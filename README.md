# TRIGGER ETL

This repository is the deliberately minimal starting point for rebuilding the
TRIGGER data pipeline from raw MariaDB tables to analysis-ready datasets.

The previous ETL implementation was removed on 2026-08-19 so that every data
specification and transformation can be reconsidered, implemented and understood
one piece at a time. Historical code remains available through Git history.

## Current state

The first complete and operationally validated component is `gps_tidy`: it
turns raw GPS readings into one unambiguous, technically valid observation per
participant and UTC minute.

It includes:

- a documented destructive tidy specification;
- one parameterless procedure that automatically chooses a full or incremental
  refresh;
- incremental selection based on `MAX(gps_tidy.created_at)`;
- transactional rebuilding of all affected event dates.

The second component, `myair_tidy`, uses the same automatic full-or-incremental
model and has completed full-build and incremental operational validation.

The third component under review is `smartwatchlow_tidy`. Its SQL and data
specification are based on a complete raw snapshot profile. The source and
participant-mapping schemas and existing indexes have been verified;
mapping cardinality and mapping-related row losses have also been inspected,
while final deduplication losses and deployment still require primary-database
validation.

The fourth component under review is `smartwatchhigh_tidy`. Its historical
rules were compared with a complete compressed raw snapshot, and its new full
and incremental procedure has passed local synthetic MariaDB execution tests.
The source schema, indexes, participant mapping and aggregate mapping losses
still require read-only validation on the primary database before deployment.

The fifth component under review is `sleep_tidy`. Its complete compressed raw
snapshot has been profiled, and the nightly grain, reference-date limitations,
latest-version rule and conservative measurement cleaning are documented. Its
new full and incremental procedure has passed local synthetic MariaDB execution
tests. The source schema, indexes, participant mapping and aggregate mapping
losses still require read-only validation on the primary database.

Canonical five-minute definitions are now implemented for GPS, MyAir and both
smartwatch streams. They use the common `(userId, bucket_5min)` key, retain
measurement-specific availability counts and have passed local synthetic
MariaDB execution tests. Their first procedures are full-only: this preserves
correctness when a later tidy correction removes a previously materialized
minute. Production runtime, lock use and a deletion-aware propagation design
must be reviewed before adding incremental refresh.

Canonical hourly definitions are now also implemented for GPS, MyAir and both
smartwatch streams. They use `(userId, hour_ts)`, give each observed
five-minute bucket equal temporal weight and retain both bucket-level and
underlying minute-level availability. Provenance is never selected arbitrarily
across a transition. These procedures have passed local synthetic MariaDB
tests and remain full-only and undeployed.

Sleep remains participant-night data and is not expanded artificially to five
minutes or hours.

Canonical daily definitions are now implemented for the same four continuous
streams. They use `(userId, date)` in UTC, weight each available hourly mean
equally and retain general and measurement-specific five-minute coverage
profiles as fixed JSON arrays ordered from hour 00 through 23. The historical
`five_min_n` and `<measurement>_5min_n` names are retained for compatibility
with the current coverage analyses. The daily procedures passed local
synthetic MariaDB tests and remain full-only and undeployed.

## Intended direction

```text
raw -> tidy -> canonical 5-minute -> optional hourly/daily -> analysis marts
```

The raw database remains immutable. The tidy layer will be intentionally
selective: it should keep only documented data needed downstream and may
discard unusable rows, values and columns. Every destructive rule must still be
explicit and accompanied by aggregate row-loss diagnostics.

The main analytical target is a participant-level five-minute dataset with an
explicit timezone and a key that supports one-to-one joins across streams.
Device and firmware information should be retained as provenance where useful,
but their role in participant-level consolidation must be decided explicitly.

## Working principles

- build one stream and one layer at a time;
- use the primary TRIGGER database as the representative source for read-only
  inspection and validation of real edge cases;
- require an explicit target and confirmation before changing database objects;
- keep database names and internal environment topology out of the repository;
- keep raw tables read-only;
- document grain, keys, units and exclusions before writing SQL;
- use small synthetic fixtures for validation;
- keep analysis-specific transformations in `trigger-analyses`;
- prefer a small understandable implementation over a generic framework.

Detailed project instructions and the decisions inherited from the initial
audit are in [AGENTS.md](AGENTS.md).

The minimum database privileges and the raw-table safety boundary are described
in [docs/database-permissions.md](docs/database-permissions.md).

The stream-specific rules and limitations are in:

- [docs/gps-tidy-specification.md](docs/gps-tidy-specification.md);
- [docs/myair-tidy-specification.md](docs/myair-tidy-specification.md);
- [docs/smartwatchlow-tidy-specification.md](docs/smartwatchlow-tidy-specification.md);
- [docs/smartwatchhigh-tidy-specification.md](docs/smartwatchhigh-tidy-specification.md);
- [docs/sleep-tidy-specification.md](docs/sleep-tidy-specification.md);
- [docs/gps-5min-specification.md](docs/gps-5min-specification.md);
- [docs/myair-5min-specification.md](docs/myair-5min-specification.md);
- [docs/smartwatchlow-5min-specification.md](docs/smartwatchlow-5min-specification.md);
- [docs/smartwatchhigh-5min-specification.md](docs/smartwatchhigh-5min-specification.md);
- [docs/gps-hourly-specification.md](docs/gps-hourly-specification.md);
- [docs/myair-hourly-specification.md](docs/myair-hourly-specification.md);
- [docs/smartwatchlow-hourly-specification.md](docs/smartwatchlow-hourly-specification.md);
- [docs/smartwatchhigh-hourly-specification.md](docs/smartwatchhigh-hourly-specification.md);
- [docs/gps-daily-specification.md](docs/gps-daily-specification.md);
- [docs/myair-daily-specification.md](docs/myair-daily-specification.md);
- [docs/smartwatchlow-daily-specification.md](docs/smartwatchlow-daily-specification.md);
- [docs/smartwatchhigh-daily-specification.md](docs/smartwatchhigh-daily-specification.md).

## Next step

The next operational step is validation one stream and one layer at a time,
beginning with the small GPS five-minute, hourly and daily chain after
confirming that `gps_tidy` is current. SmartwatchLow, SmartwatchHigh and Sleep
still require their outstanding primary tidy validation before dependent
layers can be deployed. Applying or executing SQL against a database remains
a separate, explicitly confirmed action.
