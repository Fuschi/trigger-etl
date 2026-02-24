#!/usr/bin/env bash
set -euo pipefail

ts() { date +"%Y-%m-%d %H:%M:%S"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/deploy_sql_$(date +'%Y%m%d_%H%M%S').log"

ENV_NAME="main"   # main|dev
DB_MAIN="triggerIO"
DB_DEV="triggerIO-dev"

usage() {
  cat <<EOF
Usage: $0 [--env main|dev] [<sql-file> ...]
If no sql files are provided, all files in etl/sql/*.sql are applied.
EOF
  exit 0
}

# ---- parse args ----
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_NAME="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

if [[ "$ENV_NAME" == "dev" ]]; then
  DB_NAME="$DB_DEV"
else
  DB_NAME="$DB_MAIN"
fi

# default: all sql
if [[ ${#args[@]} -eq 0 ]]; then
  args=( "${REPO_DIR}/etl/sql/"*.sql )
fi

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] SQL deploy started (env=${ENV_NAME}, db=${DB_NAME})" | tee -a "$LOG_FILE"

for sql_file in "${args[@]}"; do
  if [[ ! -f "$sql_file" ]]; then
    echo "[$(ts)] ERROR: File not found: $sql_file" | tee -a "$LOG_FILE"
    exit 2
  fi

  echo "[$(ts)] Applying: $sql_file" | tee -a "$LOG_FILE"
  mysql --database="$DB_NAME" < "$sql_file" >>"$LOG_FILE" 2>&1
  echo "[$(ts)] OK: $sql_file" | tee -a "$LOG_FILE"
done

echo "[$(ts)] SQL deploy finished" | tee -a "$LOG_FILE"