#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# run_etl.sh
#
# Executes ETL stored procedures that generate:
#   - cleaned and deduplicated tidy tables
#   - materialized five-minute sensor aggregations
#
# For each ETL step, the script logs:
#   - execution time
#   - final row count
#
# Usage:
#   ./run_etl.sh
#   ./run_etl.sh --env main|dev
#   ./run_etl.sh -h | --help
#
# Notes:
# - Uses a lock file to prevent overlapping runs.
# - Assumes MariaDB/MySQL authentication is already configured.
# - Tidy procedures must run before their five-minute
#   aggregation procedures.
# - Sleep data are already natively daily/nightly and
#   therefore have no five-minute aggregation.
# - Edit the "ETL STEPS" section to change the pipeline.
# =========================================================

ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

usage() {
  cat <<'EOF'
run_etl.sh

Executes predefined ETL stored procedures that generate:
  - cleaned and deduplicated tidy tables
  - materialized five-minute sensor aggregations

For each step, the script logs:
  - execution time
  - final row count

Usage:
  ./run_etl.sh [--env main|dev]
  ./run_etl.sh -h | --help

Options:
  -h, --help          Show this help message and exit
  --env main|dev      Select database (default: main)

The pipeline runs all tidy procedures first and then the
five-minute aggregation procedures.

Sleep data are already daily/nightly and do not have a
five-minute aggregation.

Edit the "ETL STEPS" section at the bottom of the script
to add or remove stored procedure calls.

Examples:
  run_call "etl_myair_tidy" "myair_tidy"
  run_call "etl_myair_5min" "myair_5min"
EOF

  exit 0
}

die() {
  echo "[$(ts)] ERROR: $*" | tee -a "$LOG_FILE" >&2
  exit 1
}

# =========================================================
# ARGUMENTS
# =========================================================
ENV_NAME="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;

    --env)
      [[ -n "${2:-}" ]] || {
        echo "Missing value for --env" >&2
        exit 2
      }

      ENV_NAME="$2"
      shift 2
      ;;

    *)
      echo "Unknown argument: $1" >&2
      echo "Use --help for usage." >&2
      exit 2
      ;;
  esac
done

DB_MAIN="triggerIO"
DB_DEV="triggerIO-dev"

case "$ENV_NAME" in
  main)
    DB_NAME="$DB_MAIN"
    ;;

  dev)
    DB_NAME="$DB_DEV"
    ;;

  *)
    echo "Invalid --env value: $ENV_NAME (expected: main|dev)" >&2
    exit 2
    ;;
esac

# =========================================================
# PATHS AND LOGS
# =========================================================
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"

mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/run_etl_$(date +'%Y%m%d').log"

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] ETL run started (env=${ENV_NAME}, db=${DB_NAME})" \
  | tee -a "$LOG_FILE"

# =========================================================
# LOCK
# =========================================================
LOCK_FILE="${LOG_DIR}/run_etl.lock"
exec 9>"$LOCK_FILE"

flock -n 9 || {
  echo "[$(ts)] Another ETL is running. Exiting." \
    | tee -a "$LOG_FILE"
  exit 0
}

# =========================================================
# PROCEDURE RUNNER
# =========================================================
run_call() {
  local proc="$1"
  local table="${2:-}"

  echo "----------------------------------------------------" >>"$LOG_FILE"
  echo "[$(ts)] CALL ${DB_NAME}.${proc}()" | tee -a "$LOG_FILE"

  local start
  local end

  start=$(date +%s)

  # The target database is already selected with --database.
  if ! mysql \
    --database="$DB_NAME" \
    -e "CALL \`${proc}\`();" \
    >>"$LOG_FILE" 2>&1
  then
    die "CALL ${DB_NAME}.${proc}() failed"
  fi

  end=$(date +%s)

  echo "[$(ts)] Duration: $((end - start))s" \
    | tee -a "$LOG_FILE"

  if [[ -n "$table" ]]; then
    local rows

    if ! rows=$(
      mysql \
        --database="$DB_NAME" \
        --batch \
        --skip-column-names \
        -e "SELECT COUNT(*) FROM \`${table}\`;" \
        2>>"$LOG_FILE"
    )
    then
      die "Row count query failed for ${DB_NAME}.${table}"
    fi

    echo "[$(ts)] ${DB_NAME}.${table} rows: ${rows}" \
      | tee -a "$LOG_FILE"
  fi
}

# =========================================================
# ETL STEPS
#
# All tidy tables must be rebuilt before the five-minute
# aggregation tables that depend on them.
# =========================================================

# ---- TIDY TABLES ----
run_call "etl_myair_tidy"           "myair_tidy"
run_call "etl_smartwatchhigh_tidy"  "smartwatchhigh_tidy"
run_call "etl_smartwatchlow_tidy"   "smartwatchlow_tidy"
run_call "etl_gps_tidy"             "gps_tidy"
run_call "etl_sleep_tidy"           "sleep_tidy"

# ---- FIVE-MINUTE TABLES ----
run_call "etl_myair_5min"           "myair_5min"
run_call "etl_smartwatchhigh_5min"  "smartwatchhigh_5min"
run_call "etl_smartwatchlow_5min"   "smartwatchlow_5min"
run_call "etl_gps_5min"             "gps_5min"

# ---- HOURLY TABLES ----
run_call "etl_myair_hourly"           "myair_hourly"
run_call "etl_smartwatchhigh_hourly"  "smartwatchhigh_hourly"
run_call "etl_smartwatchlow_hourly"   "smartwatchlow_hourly"
run_call "etl_gps_hourly"             "gps_hourly"

# ---- DAILY TABLES ----
run_call "etl_myair_daily"           "myair_hourly"
run_call "etl_smartwatchhigh_daily"  "smartwatchhigh_hourly"
run_call "etl_smartwatchlow_daily"   "smartwatchlow_hourly"
run_call "etl_gps_daily"             "gps_hourly"

echo "[$(ts)] ETL run finished" | tee -a "$LOG_FILE"
