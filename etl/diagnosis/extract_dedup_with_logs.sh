#!/usr/bin/env bash
# =========================================================
# extract_dedup_with_logs.sh
#
# Extracts de-duplicated tables without validity filters
# directly to gzipped TSV files.
#
# It also writes row-count logs for each preprocessing step.
#
# Nothing is written to the database:
#   - read-only SELECT queries only
#   - output tables are written as gzipped TSV files
#   - row-count logs are written as TSV files
#
# Usage:
#   bash extract_dedup_with_logs.sh
#   bash extract_dedup_with_logs.sh /path/to/output_folder
#
# Output tables:
#   myair_dedup_raw.tsv.gz
#   smartwatchhigh_dedup_raw.tsv.gz
#   smartwatchlow_dedup_raw.tsv.gz
#   gps_dedup_raw.tsv.gz
#   sleep_dedup_raw.tsv.gz
#
# Output logs, in the same output folder:
#   log_myair_dedup.tsv
#   log_smartwatchhigh_dedup.tsv
#   log_smartwatchlow_dedup.tsv
#   log_gps_dedup.tsv
#   log_sleep_dedup.tsv
#   dedup_row_counts_all.tsv
# =========================================================

set -euo pipefail

DB="triggerIO"
DB_USER="alessandro.fuschi2"

if [ "$#" -gt 1 ]; then
  echo "Usage:"
  echo "  bash extract_dedup_with_logs.sh"
  echo "  bash extract_dedup_with_logs.sh /path/to/output_folder"
  exit 1
fi

# Output directory:
# - if an argument is provided, use it
# - otherwise, use the current directory
OUTDIR="${1:-$(pwd)}"

# Create output directory if it does not exist
mkdir -p "$OUTDIR"

# Convert output directory to absolute path
OUTDIR="$(cd "$OUTDIR" && pwd -P)"

# Logs are written in the same output directory
LOGDIR="$OUTDIR"

read -s -p "MySQL password for $DB_USER: " PW
echo ""

mysql_cmd() {
  mysql -u "$DB_USER" -p"$PW" "$DB" --batch --raw "$@"
}

# =========================================================
# Generic row-count log SQL for time-series tables
#
# Applies to:
#   myair
#   smartwatchhigh
#   smartwatchlow
#   gps
#
# Steps:
#   1. raw
#   2. dedup_created_at
#   3. dedup_minute_level
#   4. dedup_unique_user_device
# =========================================================

timeseries_log_sql() {
  local name="$1"
  local raw_table="$2"
  local user_table="$3"

  cat <<SQL
WITH
s AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    created_at,
    MIN(created_at) OVER (
      PARTITION BY deviceId, firmware, event_ts
    ) AS min_ca,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware, event_ts, created_at
    ) AS cnt_ca
  FROM ${raw_table}
),

second_dedup AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    created_at
  FROM s
  WHERE created_at = min_ca
    AND cnt_ca = 1
),

m AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    created_at,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware,
                   DATE(event_ts), HOUR(event_ts), MINUTE(event_ts)
    ) AS cnt_min
  FROM second_dedup
),

minute_dedup AS (
  SELECT
    deviceId,
    firmware,
    event_ts,
    created_at
  FROM m
  WHERE cnt_min = 1
),

u AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM ${user_table}
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

user_validated AS (
  SELECT
    u.userId,
    d.deviceId,
    d.firmware,
    d.event_ts,
    d.created_at
  FROM minute_dedup AS d
  JOIN u
    ON u.deviceId = d.deviceId
)

SELECT '${name}' AS data_stream, 1 AS step_order, 'raw' AS step, COUNT(*) AS n_rows
FROM ${raw_table}

UNION ALL

SELECT '${name}' AS data_stream, 2 AS step_order, 'dedup_created_at' AS step, COUNT(*) AS n_rows
FROM second_dedup

UNION ALL

SELECT '${name}' AS data_stream, 3 AS step_order, 'dedup_minute_level' AS step, COUNT(*) AS n_rows
FROM minute_dedup

UNION ALL

SELECT '${name}' AS data_stream, 4 AS step_order, 'dedup_unique_user_device' AS step, COUNT(*) AS n_rows
FROM user_validated

ORDER BY step_order;
SQL
}

# =========================================================
# Sleep row-count log SQL
#
# Sleep is different because it has no event_ts.
#
# Steps:
#   1. raw
#   2. date_built
#   3. dedup_day_level
#   4. dedup_unique_user_device
# =========================================================

sleep_log_sql() {
  cat <<SQL
WITH
sw AS (
  SELECT
    deviceId,
    firmware,
    created_at,
    STR_TO_DATE(
      CONCAT(year, '-', LPAD(month, 2, '0'), '-', LPAD(day, 2, '0')),
      '%Y-%m-%d'
    ) AS date
  FROM sleep
),

sw_valid_date AS (
  SELECT *
  FROM sw
  WHERE date IS NOT NULL
),

bmin AS (
  SELECT
    deviceId,
    firmware,
    date,
    MIN(created_at) AS min_ca
  FROM sw_valid_date
  GROUP BY deviceId, firmware, date
),

bcnt AS (
  SELECT
    deviceId,
    firmware,
    date,
    created_at,
    COUNT(*) AS cnt
  FROM sw_valid_date
  GROUP BY deviceId, firmware, date, created_at
),

buniq AS (
  SELECT
    m.deviceId,
    m.firmware,
    m.date,
    m.min_ca
  FROM bmin AS m
  JOIN bcnt AS c
    ON c.deviceId   = m.deviceId
   AND c.firmware   = m.firmware
   AND c.date       = m.date
   AND c.created_at = m.min_ca
  WHERE c.cnt = 1
),

day_dedup AS (
  SELECT
    s.deviceId,
    s.firmware,
    s.date,
    s.created_at
  FROM sw_valid_date AS s
  JOIN buniq AS b
    ON s.deviceId   = b.deviceId
   AND s.firmware   = b.firmware
   AND s.date       = b.date
   AND s.created_at = b.min_ca
),

u AS (
  SELECT
    deviceId,
    MIN(userId) AS userId
  FROM user_sleep
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
),

user_validated AS (
  SELECT
    u.userId,
    d.deviceId,
    d.firmware,
    d.date,
    d.created_at
  FROM day_dedup AS d
  JOIN u
    ON u.deviceId = d.deviceId
)

SELECT 'sleep' AS data_stream, 1 AS step_order, 'raw' AS step, COUNT(*) AS n_rows
FROM sleep

UNION ALL

SELECT 'sleep' AS data_stream, 2 AS step_order, 'date_built' AS step, COUNT(*) AS n_rows
FROM sw_valid_date

UNION ALL

SELECT 'sleep' AS data_stream, 3 AS step_order, 'dedup_day_level' AS step, COUNT(*) AS n_rows
FROM day_dedup

UNION ALL

SELECT 'sleep' AS data_stream, 4 AS step_order, 'dedup_unique_user_device' AS step, COUNT(*) AS n_rows
FROM user_validated

ORDER BY step_order;
SQL
}

# =========================================================
# Write row-count log
# =========================================================

write_log() {
  local name="$1"
  local sql="$2"
  local log="$LOGDIR/log_${name}_dedup.tsv"

  echo "[$(date '+%H:%M:%S')] $name log..."

  {
    printf "data_stream\tstep_order\tstep\tn_rows\n"
    mysql_cmd --skip-column-names -e "$sql"
  } > "$log"

  echo "[$(date '+%H:%M:%S')] -> $log"
}

# =========================================================
# Extract gzipped TSV
# =========================================================

run_extract() {
  local name="$1"
  local sql="$2"
  local out="$OUTDIR/${name}_dedup_raw.tsv.gz"

  echo "[$(date '+%H:%M:%S')] $name extract..."

  mysql_cmd -e "$sql" | gzip > "$out"

  echo "[$(date '+%H:%M:%S')] -> $out ($(du -h "$out" | cut -f1))"
}

# =========================================================
# Run one data stream:
#   1. write row-count log
#   2. extract de-duplicated raw table
# =========================================================

run_table() {
  local name="$1"
  local log_sql="$2"
  local extract_sql="$3"

  write_log "$name" "$log_sql"
  run_extract "$name" "$extract_sql"
}

# =========================================================
# Extraction SQL queries
# =========================================================

MYAIR_EXTRACT_SQL="
WITH
s AS (
  SELECT *,
    MIN(created_at) OVER (
      PARTITION BY deviceId, firmware, event_ts
    ) AS min_ca,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware, event_ts, created_at
    ) AS cnt_ca
  FROM myair
),
m AS (
  SELECT *,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware,
                   DATE(event_ts), HOUR(event_ts), MINUTE(event_ts)
    ) AS cnt_min
  FROM s
  WHERE created_at = min_ca
    AND cnt_ca = 1
),
u AS (
  SELECT deviceId, MIN(userId) AS userId
  FROM user_myair
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
)
SELECT
  u.userId,
  d.deviceId,
  d.firmware,
  d.event_ts,
  d.created_at,
  d.pm1,
  d.pm25,
  d.pm10,
  d.pc03,
  d.pc05,
  d.pc1,
  d.pc25,
  d.pc5,
  d.pc10,
  d.temperature,
  d.humidity,
  d.pressure,
  d.sound,
  d.uvb,
  d.light
FROM m AS d
JOIN u
  ON u.deviceId = d.deviceId
WHERE d.cnt_min = 1;
"

SMARTWATCHHIGH_EXTRACT_SQL="
WITH
s AS (
  SELECT *,
    MIN(created_at) OVER (
      PARTITION BY deviceId, firmware, event_ts
    ) AS min_ca,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware, event_ts, created_at
    ) AS cnt_ca
  FROM smartwatchhigh
),
m AS (
  SELECT *,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware,
                   DATE(event_ts), HOUR(event_ts), MINUTE(event_ts)
    ) AS cnt_min
  FROM s
  WHERE created_at = min_ca
    AND cnt_ca = 1
),
u AS (
  SELECT deviceId, MIN(userId) AS userId
  FROM user_smartwatchhigh
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
)
SELECT
  u.userId,
  d.deviceId,
  d.firmware,
  d.event_ts,
  d.created_at,
  d.heartrate,
  d.oxygens,
  d.breathrate,
  d.sleeprate
FROM m AS d
JOIN u
  ON u.deviceId = d.deviceId
WHERE d.cnt_min = 1;
"

SMARTWATCHLOW_EXTRACT_SQL="
WITH
s AS (
  SELECT *,
    MIN(created_at) OVER (
      PARTITION BY deviceId, firmware, event_ts
    ) AS min_ca,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware, event_ts, created_at
    ) AS cnt_ca
  FROM smartwatchlow
),
m AS (
  SELECT *,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware,
                   DATE(event_ts), HOUR(event_ts), MINUTE(event_ts)
    ) AS cnt_min
  FROM s
  WHERE created_at = min_ca
    AND cnt_ca = 1
),
u AS (
  SELECT deviceId, MIN(userId) AS userId
  FROM user_smartwatchlow
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
)
SELECT
  u.userId,
  d.deviceId,
  d.firmware,
  d.event_ts,
  d.created_at,
  d.step,
  d.cal,
  d.bphigh,
  d.bplow,
  d.bodytemp,
  d.skintemp
FROM m AS d
JOIN u
  ON u.deviceId = d.deviceId
WHERE d.cnt_min = 1;
"

GPS_EXTRACT_SQL="
WITH
s AS (
  SELECT *,
    MIN(created_at) OVER (
      PARTITION BY deviceId, firmware, event_ts
    ) AS min_ca,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware, event_ts, created_at
    ) AS cnt_ca
  FROM gps
),
m AS (
  SELECT *,
    COUNT(*) OVER (
      PARTITION BY deviceId, firmware,
                   DATE(event_ts), HOUR(event_ts), MINUTE(event_ts)
    ) AS cnt_min
  FROM s
  WHERE created_at = min_ca
    AND cnt_ca = 1
),
u AS (
  SELECT deviceId, MIN(userId) AS userId
  FROM user_gps
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
)
SELECT
  u.userId,
  d.deviceId,
  d.firmware,
  d.event_ts,
  d.created_at,
  d.longitude,
  d.latitude,
  d.accuracy
FROM m AS d
JOIN u
  ON u.deviceId = d.deviceId
WHERE d.cnt_min = 1;
"

SLEEP_EXTRACT_SQL="
WITH
sw AS (
  SELECT *,
    STR_TO_DATE(
      CONCAT(year, '-', LPAD(month, 2, '0'), '-', LPAD(day, 2, '0')),
      '%Y-%m-%d'
    ) AS date
  FROM sleep
),
sw_valid_date AS (
  SELECT *
  FROM sw
  WHERE date IS NOT NULL
),
bmin AS (
  SELECT
    deviceId,
    firmware,
    date,
    MIN(created_at) AS min_ca
  FROM sw_valid_date
  GROUP BY deviceId, firmware, date
),
bcnt AS (
  SELECT
    deviceId,
    firmware,
    date,
    created_at,
    COUNT(*) AS cnt
  FROM sw_valid_date
  GROUP BY deviceId, firmware, date, created_at
),
buniq AS (
  SELECT
    m.deviceId,
    m.firmware,
    m.date,
    m.min_ca
  FROM bmin AS m
  JOIN bcnt AS c
    ON c.deviceId   = m.deviceId
   AND c.firmware   = m.firmware
   AND c.date       = m.date
   AND c.created_at = m.min_ca
  WHERE c.cnt = 1
),
dedup AS (
  SELECT s.*
  FROM sw_valid_date AS s
  JOIN buniq AS b
    ON s.deviceId   = b.deviceId
   AND s.firmware   = b.firmware
   AND s.date       = b.date
   AND s.created_at = b.min_ca
),
u AS (
  SELECT deviceId, MIN(userId) AS userId
  FROM user_sleep
  GROUP BY deviceId
  HAVING COUNT(DISTINCT userId) = 1
)
SELECT
  u.userId,
  d.deviceId,
  d.firmware,
  d.date,
  d.created_at,
  d.sleepduration,
  d.awake,
  d.insomnia,
  d.remsleep,
  d.lightsleep,
  d.deepsleep,
  d.sleepquality,
  d.fallsleepefficiency
FROM dedup AS d
JOIN u
  ON u.deviceId = d.deviceId;
"

# =========================================================
# Run all data streams in parallel
# =========================================================

echo "Output directory: $OUTDIR"

run_table "myair" \
  "$(timeseries_log_sql "myair" "myair" "user_myair")" \
  "$MYAIR_EXTRACT_SQL" &

run_table "smartwatchhigh" \
  "$(timeseries_log_sql "smartwatchhigh" "smartwatchhigh" "user_smartwatchhigh")" \
  "$SMARTWATCHHIGH_EXTRACT_SQL" &

run_table "smartwatchlow" \
  "$(timeseries_log_sql "smartwatchlow" "smartwatchlow" "user_smartwatchlow")" \
  "$SMARTWATCHLOW_EXTRACT_SQL" &

run_table "gps" \
  "$(timeseries_log_sql "gps" "gps" "user_gps")" \
  "$GPS_EXTRACT_SQL" &

run_table "sleep" \
  "$(sleep_log_sql)" \
  "$SLEEP_EXTRACT_SQL" &

wait

# =========================================================
# Combined log in the same output folder
# =========================================================

{
  printf "data_stream\tstep_order\tstep\tn_rows\n"

  for f in "$LOGDIR"/log_*_dedup.tsv; do
    tail -n +2 "$f"
  done
} > "$LOGDIR/dedup_row_counts_all.tsv"

echo "[$(date '+%H:%M:%S')] All done."
echo "Output directory: $OUTDIR"
echo "Combined log: $OUTDIR/dedup_row_counts_all.tsv"
