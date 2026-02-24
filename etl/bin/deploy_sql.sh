#!/usr/bin/env bash
set -euo pipefail

# =========================================================
# deploy_sql.sh
#
# Deploy SQL objects to MariaDB using local socket.
# Assumes unix_socket authentication (no password needed).
# =========================================================

ts() { date +"%Y-%m-%d %H:%M:%S"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="${REPO_DIR}/logs"
mkdir -p "$LOG_DIR"

LOG_FILE="${LOG_DIR}/deploy_sql_$(date +'%Y%m%d').log"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <sql-file> [<sql-file> ...]" >&2
  exit 1
fi

echo "====================================================" >>"$LOG_FILE"
echo "[$(ts)] SQL deploy started" | tee -a "$LOG_FILE"

for sql_file in "$@"; do
  if [[ ! -f "$sql_file" ]]; then
    echo "[$(ts)] ERROR: File not found: $sql_file" | tee -a "$LOG_FILE"
    exit 2
  fi

  echo "[$(ts)] Applying: $sql_file" | tee -a "$LOG_FILE"
  mysql < "$sql_file" >>"$LOG_FILE" 2>&1
  echo "[$(ts)] OK: $sql_file" | tee -a "$LOG_FILE"
done

echo "[$(ts)] SQL deploy finished" | tee -a "$LOG_FILE"