#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# run_etl.sh
#
# Executes ETL stored procedures that generate cleaned and
# deduplicated tidy tables, and logs:
#   - execution time
#   - final row count (if table provided)
#
# Usage:
#   ./run_etl.sh
#   ./run_etl.sh --env main|dev
#   ./run_etl.sh -h | --help
#
# Notes:
# - Uses a lock file to prevent overlapping runs.
# - Assumes MariaDB/MySQL auth is already configured (e.g. unix_socket).
# - Edit the "ETL STEPS" section at the bottom to change the pipeline.
# =========================================================

ts() { date +"%Y-%m-%d %H:%M:%S"; }

usage() {
  cat <<'EOF'
run_etl.sh

Executes predefined ETL stored procedures that generate cleaned and
deduplicated tidy tables, and logs:
  - execution time
  - final row count (if table provided)

Usage:
  ./run_etl.sh [--env main|dev]
  ./run_etl.sh -h | --help

Options:
  -h, --help          Show this help message and exit
  --env main|dev      Select database (default: main)

Edit the "ETL STEPS" section at the bottom of the script
to add or remove stored procedure calls.

Example:
  run_call "etl_myair_tidy" "myair_tidy"
EOF
  exit 0
}

die() {
  echo "[$(ts)] ERROR: $*" | tee -a "$LOG_FILE" >&2
  exit 1
}

# ---- args ----
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
  main) DB_NAME="$DB_MAIN" ;;
  dev)  DB_NAME="$DB_DEV"  ;;
  *)
    echo "Invalid --env value: $ENV_NAME (expected: main|dev)" >&2
    exit 2
    ;;
esac

# ---- paths/logs ----
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/run_etl_$(date +'%Y%m%d').log"

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] ETL run started (env=${ENV_NAME}, db=${DB_NAME})" \
  | tee -a "$LOG_FILE"

# ---- lock ----
LOCK_FILE="${LOG_DIR}/run_etl.lock"
exec 9>"$LOCK_FILE"

flock -n 9 || {
  echo "[$(ts)] Another ETL is running. Exiting." \
    | tee -a "$LOG_FILE"
  exit 0
}

# ---- runner ----
run_call() {
  local proc="$1"
  local table="${2:-}"

  echo "----------------------------------------------------" >>"$LOG_FILE"
  echo "[$(ts)] CALL ${DB_NAME}.${proc}()" | tee -a "$LOG_FILE"

  local start end
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

# ---- ETL STEPS ----
run_call "etl_myair_tidy"           "myair_tidy"
run_call "etl_smartwatchhigh_tidy"  "smartwatchhigh_tidy"
run_call "etl_smartwatchlow_tidy"   "smartwatchlow_tidy"
run_call "etl_gps_tidy"             "gps_tidy"
run_call "etl_sleep_tidy"           "sleep_tidy"

echo "[$(ts)] ETL run finished" | tee -a "$LOG_FILE"
