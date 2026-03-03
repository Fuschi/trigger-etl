#!/usr/bin/env bash
set -euo pipefail

ts() { date +"%Y-%m-%d %H:%M:%S"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/deploy_sql_$(date +'%Y%m%d_%H%M%S').log"

# =========================================================
# HELP
# =========================================================
usage() {
  cat <<EOF
SQL deploy

This script applies the SQL files listed in SQL_FILES to both databases
(triggerIO-dev and triggerIO). It is meant to deploy table definitions
(e.g. hourly tables) and stored procedures you write to generate clean
or aggregated datasets (for example daily rollups).

Edit DATABASES and SQL_FILES inside the script to control what is deployed.
The SQL files are applied in the given order.

Usage: $0
Options: -h, --help   Show this help and exit
Logs:   ${LOG_FILE}
EOF
  exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# =========================================================
# CONFIG: target databases (dev first, then main)
# =========================================================
DATABASES=(
  "triggerIO-dev"
  "triggerIO"
)

# =========================================================
# CONFIG: SQL files to apply (ORDER MATTERS)
# =========================================================
SQL_FILES=(
  "${REPO_DIR}/etl/sql/rebuild_myair_hourly.sql"
  "${REPO_DIR}/etl/sql/rebuild_smartwatchhigh_hourly.sql"
  "${REPO_DIR}/etl/sql/rebuild_smartwatchlow_hourly.sql"
  "${REPO_DIR}/etl/sql/rebuild_gps_hourly.sql"
  # ...
)

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] SQL deploy started" | tee -a "$LOG_FILE"
echo "[$(ts)] Targets: ${DATABASES[*]}" | tee -a "$LOG_FILE"

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "[$(ts)] ERROR: SQL_FILES is empty. Nothing to deploy." | tee -a "$LOG_FILE"
  exit 2
fi

echo "[$(ts)] Files:" | tee -a "$LOG_FILE"
for f in "${SQL_FILES[@]}"; do
  echo "  - $f" | tee -a "$LOG_FILE"
done

for DB_NAME in "${DATABASES[@]}"; do
  echo "----------------------------------------------------" | tee -a "$LOG_FILE"
  echo "[$(ts)] Deploying to: $DB_NAME" | tee -a "$LOG_FILE"

  for sql_file in "${SQL_FILES[@]}"; do
    if [[ ! -f "$sql_file" ]]; then
      echo "[$(ts)] ERROR: File not found: $sql_file" | tee -a "$LOG_FILE"
      exit 2
    fi

    echo "[$(ts)] Applying: $sql_file" | tee -a "$LOG_FILE"
    mysql --database="$DB_NAME" < "$sql_file" >>"$LOG_FILE" 2>&1
    echo "[$(ts)] OK: $sql_file" | tee -a "$LOG_FILE"
  done
done

echo "====================================================" | tee -a "$LOG_FILE"
echo "[$(ts)] SQL deploy finished successfully" | tee -a "$LOG_FILE"