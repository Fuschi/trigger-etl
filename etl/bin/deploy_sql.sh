#!/usr/bin/env bash
set -euo pipefail

ts() {
  date +"%Y-%m-%d %H:%M:%S"
}

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

This script applies the SQL files listed in SQL_FILES to both databases:
  - triggerIO-dev
  - triggerIO

It deploys the table definitions and stored procedures used to generate
cleaned and deduplicated tidy datasets while preserving the original
temporal resolution of the observations.

Edit DATABASES and SQL_FILES inside the script to control what is deployed.
The SQL files are applied in the specified order.

Usage:
  $0

Options:
  -h, --help    Show this help message and exit

Logs:
  ${LOG_FILE}
EOF

  exit 0
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

# =========================================================
# CONFIG: target databases
# Development is deployed first, followed by main.
# =========================================================
DATABASES=(
  "triggerIO-dev"
  "triggerIO"
)

# =========================================================
# CONFIG: SQL files to apply
# ORDER MATTERS
# =========================================================
SQL_FILES=(
  "${REPO_DIR}/etl/sql/sp_active_accounts.sql"
  "${REPO_DIR}/etl/sql/etl_myair_tidy.sql"
  "${REPO_DIR}/etl/sql/etl_smartwatchhigh_tidy.sql"
  "${REPO_DIR}/etl/sql/etl_smartwatchlow_tidy.sql"
  "${REPO_DIR}/etl/sql/etl_gps_tidy.sql"
  "${REPO_DIR}/etl/sql/etl_sleep_tidy.sql"
)

# =========================================================
# DEPLOY
# =========================================================
echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] SQL deploy started" | tee -a "$LOG_FILE"
echo "[$(ts)] Repository: ${REPO_DIR}" | tee -a "$LOG_FILE"
echo "[$(ts)] Targets: ${DATABASES[*]}" | tee -a "$LOG_FILE"

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "[$(ts)] ERROR: SQL_FILES is empty. Nothing to deploy." \
    | tee -a "$LOG_FILE"
  exit 2
fi

echo "[$(ts)] SQL files:" | tee -a "$LOG_FILE"

for sql_file in "${SQL_FILES[@]}"; do
  echo "  - ${sql_file}" | tee -a "$LOG_FILE"

  if [[ ! -f "$sql_file" ]]; then
    echo "[$(ts)] ERROR: SQL file not found: ${sql_file}" \
      | tee -a "$LOG_FILE"
    exit 2
  fi
done

for DB_NAME in "${DATABASES[@]}"; do
  echo "----------------------------------------------------" | tee -a "$LOG_FILE"
  echo "[$(ts)] Deploying to database: ${DB_NAME}" \
    | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"

  for sql_file in "${SQL_FILES[@]}"; do
    echo "[$(ts)] Applying: ${sql_file}" | tee -a "$LOG_FILE"

    if mysql \
      --show-warnings \
      --database="$DB_NAME" \
      < "$sql_file" \
      2>&1 | tee -a "$LOG_FILE"
    then
      echo "[$(ts)] OK: ${sql_file}" | tee -a "$LOG_FILE"
    else
      rc=${PIPESTATUS[0]}

      echo "[$(ts)] ERROR (exit=${rc}): ${sql_file}" \
        | tee -a "$LOG_FILE"

      exit "$rc"
    fi

    echo "" | tee -a "$LOG_FILE"
  done
done

echo "====================================================" | tee -a "$LOG_FILE"
echo "[$(ts)] SQL deploy finished successfully" \
  | tee -a "$LOG_FILE"
