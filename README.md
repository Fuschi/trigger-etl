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

No five-minute, hourly or daily layer has been rebuilt yet.

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
- [docs/sleep-tidy-specification.md](docs/sleep-tidy-specification.md).

## Next step

The next Sleep step is read-only verification of its raw schema, indexes,
participant mapping and mapping-related row loss on the primary database.
Repository-level automated tests remain intentionally deferred while the
implementation is reviewed piece by piece. Applying or executing SQL against a
database remains a separate, explicitly confirmed action.
