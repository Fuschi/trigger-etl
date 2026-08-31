#!/usr/bin/env bash

# Run every installed TRIGGER ETL procedure in dependency order.
# MariaDB credentials are read from the account's normal client configuration.

set -Eeuo pipefail
umask 077

readonly database_name="${ETL_DATABASE:-${1:-}}"
readonly lock_file="${ETL_LOCK_FILE:-/tmp/trigger-etl-${UID}.lock}"
current_step="startup"

log() {
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*"
}

on_error() {
  local exit_code=$?
  log "FAILED step=${current_step} exit_code=${exit_code}"
  exit "$exit_code"
}

trap on_error ERR

if [[ -z "$database_name" ]]; then
  printf 'Usage: ETL_DATABASE=<database> %s\n' "$0" >&2
  printf '   or: %s <database>\n' "$0" >&2
  exit 64
fi

if [[ -n "${ETL_DATABASE:-}" && $# -gt 0 ]]; then
  printf 'Error: use ETL_DATABASE or one database argument, not both.\n' >&2
  exit 64
fi

if [[ $# -gt 1 ]]; then
  printf 'Error: expected at most one database argument.\n' >&2
  exit 64
fi

command -v mariadb >/dev/null                    # Fail before starting if the client is unavailable.
command -v flock >/dev/null                      # A nightly run must not overlap an earlier run.

mariadb_options=(--batch --raw)

if [[ -n "${ETL_DEFAULTS_FILE:-}" ]]; then
  if [[ ! -r "$ETL_DEFAULTS_FILE" ]]; then
    printf 'Error: ETL_DEFAULTS_FILE is not readable: %s\n' "$ETL_DEFAULTS_FILE" >&2
    exit 66
  fi
  mariadb_options=("--defaults-extra-file=$ETL_DEFAULTS_FILE" "${mariadb_options[@]}")
fi

exec 9>"$lock_file"
if ! flock -n 9; then
  log "SKIPPED reason=another_run_is_active lock=$lock_file"
  exit 75
fi

run_procedure() {
  local procedure_name=$1
  current_step="$procedure_name"
  log "START procedure=$procedure_name"
  mariadb "${mariadb_options[@]}" --database="$database_name" \
    --execute="CALL ${procedure_name}();"
  log "DONE procedure=$procedure_name"
}

readonly run_started_seconds=$SECONDS
log "ETL START database=$database_name"

# Tidy refreshes run first because every later layer depends on them.
run_procedure etl_gps_tidy
run_procedure etl_myair_tidy
run_procedure etl_smartwatchlow_tidy
run_procedure etl_smartwatchhigh_tidy
run_procedure etl_sleep_tidy

# Canonical five-minute tables are full, deletion-aware rebuilds from tidy.
run_procedure etl_gps_5min
run_procedure etl_myair_5min
run_procedure etl_smartwatchlow_5min
run_procedure etl_smartwatchhigh_5min

# Hourly tables read only their corresponding five-minute tables.
run_procedure etl_gps_hourly
run_procedure etl_myair_hourly
run_procedure etl_smartwatchlow_hourly
run_procedure etl_smartwatchhigh_hourly

# Daily tables read only their corresponding hourly tables.
run_procedure etl_gps_daily
run_procedure etl_myair_daily
run_procedure etl_smartwatchlow_daily
run_procedure etl_smartwatchhigh_daily

current_step="complete"
log "ETL DONE elapsed_seconds=$((SECONDS - run_started_seconds))"
