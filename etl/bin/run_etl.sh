#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# run_etl.sh
#
# Executes ETL stored procedures and logs:
#   - execution time
#   - final row count
#
# Usage:
#   ./run_etl.sh
#   ./run_etl.sh -h | --help
# =========================================================

ts() { date +"%Y-%m-%d %H:%M:%S"; }

usage() {
  cat <<EOF
run_etl.sh

Executes predefined ETL stored procedures and logs:
  - execution time
  - final row count (if table provided)

Options:
  -h, --help      Show this help message and exit

Edit the "ETL STEPS" section at the bottom of the script
to add or remove stored procedure calls.

Example:
  run_call "trigger.rebuild_myair_hourly" "trigger.myair_hourly"
EOF
  exit 0
}

# ---- parse args ----
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/run_etl_$(date +'%Y%m%d').log"

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] ETL run started" | tee -a "$LOG_FILE"

LOCK_FILE="${LOG_DIR}/run_etl.lock"
exec 9>"$LOCK_FILE"
flock -n 9 || { echo "[$(ts)] Another ETL is running. Exiting." | tee -a "$LOG_FILE"; exit 0; }

# ---- simple ETL runner ----
run_call() {
  local proc="$1"
  local table="${2:-}"

  echo "----------------------------------------------------" >>"$LOG_FILE"
  echo "[$(ts)] CALL ${proc}()" | tee -a "$LOG_FILE"

  start=$(date +%s)

  mysql -e "CALL ${proc}();" >>"$LOG_FILE" 2>&1

  end=$(date +%s)
  echo "[$(ts)] Duration: $((end - start))s" | tee -a "$LOG_FILE"

  if [[ -n "$table" ]]; then
    rows=$(mysql --batch --skip-column-names -e "SELECT COUNT(*) FROM ${table};")
    echo "[$(ts)] ${table} rows: ${rows}" | tee -a "$LOG_FILE"
  fi
}

# ---- ETL STEPS ----
run_call "trigger.rebuild_myair_hourly"           "trigger.myair_hourly"
run_call "trigger.rebuild_smartwatchhigh_hourly"  "trigger.smartwatchhigh_hourly"
run_call "trigger.rebuild_smartwatchlow_hourly"   "trigger.smartwatchlow_hourly"
run_call "trigger.rebuild_myair_daily"            "trigger.myair_daily"

echo "[$(ts)] ETL run finished" | tee -a "$LOG_FILE"