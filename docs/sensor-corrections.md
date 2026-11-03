# Sensor corrections and calibration status

This page summarizes the supplier clarifications received in emails with Arun,
in the thread
“Calibration factors for MyAir” (September 2026). It records how the current
ETL interprets them; the detailed cleaning contract is in
[tidy cleaning](tidy-cleaning.md#measurements). The email and its personal
contact details are not included in the repository.

## Confirmed corrections

| Email date | Clarification | Current tidy implementation |
|---|---|---|
| 24 September 2026 | MyAir sound is stored as dB × 10. | Divide valid raw `sound` by 10. |
| 24 September 2026 | MyAir UV is stored as UV index × 100. | Divide valid raw `uvb` by 100. The column name is retained; its interpreted unit is UV index. |
| 24 September 2026 | MyAir light is already in lux. | Retain non-negative `light` without rescaling. |
| 29 September 2026 | Valid PM range is 0–500 µg/m³. | Retain each PM independently within the inclusive range; otherwise set it to `NULL`. |
| 29 September 2026 | PC has no specified effective validity range; discard PC associated with invalid PM. | Require all three PM values to be valid before retaining any PC; also retain the existing technical PC range 0–65534. |
| 29 September 2026 | Raw `bodytemp` reports skin temperature; raw `skintemp` reports body temperature. Zero means no returned temperature reading. | Swap the raw labels; apply the operational bounds described below, which also exclude zero. |

An invalid cell becomes `NULL`; other usable measurements in the same row
can survive. Raw data is never changed. For PC, requiring all three PM fields
is the ETL's explicit interpretation of the association rule, not a separate
supplier-defined PC threshold.

## Provisional correction of intermittent temperature-channel swaps

The initial supplier mapping remains raw `skintemp` → tidy `bodytemp` and
raw `bodytemp` → tidy `skintemp`. Some participants show persistent periods
where this mapping appears reversed. A provisional, *study-derived* correction
is applied before temperature validity limits, using raw values from
unambiguous participant-minutes.

Within each UTC participant-day, calculate mean paired temperatures for
each five-minute bucket (both raw values must be 20–42). The vote compares
the absolute distances of the mapped body and skin temperatures from 36.5 °C:
a difference greater than 0.7 °C in favor of the mapped skin temperature
votes for an additional swap; a difference less than −0.7 °C votes against.
Other buckets abstain. Apply the additional swap to the whole UTC day only
if at least 12 buckets are classifiable and at least 80% vote for swapping.
Otherwise keep the initial supplier mapping. Then apply the 32–42 body and
20–42 skin limits. These reference values and thresholds are provisional and
are **not supplier-confirmed**.

This corrects consistent whole-day inversions; it cannot resolve within-day
changes. Incremental SmartwatchLow tidy refreshes therefore rebuild entire
affected participant-days, allowing a late upload to change the day-wide vote.
The downstream five-minute, hourly and daily tables are rebuilt from tidy.
After installing the updated procedure, a full SmartwatchLow tidy rebuild and
downstream rebuilds are required to correct historical data.

## Technical rules versus supplier confirmation

The ETL also applies documented technical bounds and sentinel exclusions.
The MyAir sound ceiling of 140 dB, UV raw range 0–6552, PC range 0–65534,
humidity range 0–100 and pressure range 300–1100 are listed with their
rationale in [tidy cleaning](tidy-cleaning.md#myair). They should not all be
read as scientific validity limits confirmed by the supplier. The sound ceiling
remains provisional.

## Calibration still unresolved

The supplier noted that internal heating affects MyAir temperature and humidity,
and that light/UV measurements depend on device orientation and usage.
He also cautioned that the calibration formulas came from another project
with similar participants. The email refers to an attached calibration
document; executable formulas have not been incorporated into this ETL.

The current code preserves MyAir temperature and filters humidity to its
existing range, without a heating correction. It applies no angle-dependent
light or UV correction. Temperature units and device-specific smartwatch temperature
validity bounds remain unconfirmed. The study now applies inclusive operational
bounds of 32–42 for tidy body temperature and 20–42 for tidy skin temperature,
assuming °C; these thresholds are not supplier-validated. Out-of-range values
become NULL independently before aggregation. Dividing stored values by 10 or 100 is
unit rescaling, not a complete physical calibration.

## UV precision: readings versus aggregate means

The raw `myair.uvb` column was verified as `INT NOT NULL` in the deployed
schema on 14 October 2026. For valid integer readings, division by 100 gives
steps of 0.01 UV index: raw 1 becomes 0.01, and raw 11 becomes 0.11.
Tidy stores the result as `DOUBLE` without decimal rounding. Two decimal
places therefore retain the decimal resolution of individual valid readings;
zeros in the raw column are already present before rescaling.

Aggregate means can have finer resolution than the readings. For example,
minute values 0.01, 0, 0, 0, 0 average to 0.002, which is stored as 0.00
after rounding to two places. This is a precision effect, not a missing value
or an excluded observation. Hourly and daily means use the already rounded
lower-layer means, so rounding also propagates through the hierarchy.
See [aggregation precision](aggregations.md#numerical-precision).

SQL implementation: [MyAir tidy](../etl/sql/myair_tidy.sql) and
[SmartwatchLow tidy](../etl/sql/smartwatchlow_tidy.sql).
