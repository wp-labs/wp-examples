#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

LINE_CNT=${LINE_CNT:-5000}
STAT_SEC=${STAT_SEC:-3}
DATA_FILE=${DATA_FILE:-./data/in_dat/gen.dat}

DORIS_HOST=${DORIS_HOST:-127.0.0.1}
DORIS_PORT=${DORIS_PORT:-9030}
DORIS_USER=${DORIS_USER:-root}
DORIS_PASSWORD=${DORIS_PASSWORD:-}
DORIS_DB=${DORIS_DB:-wp_test}
DORIS_TABLE=${DORIS_TABLE:-events_parsed}

log() {
  printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

for cmd in wproj wpgen wparse; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Error: required command '$cmd' not found in PATH" >&2
    exit 1
  fi
done

log "check project layout"
wproj check || true

log "cleanup historical data"
wproj data clean || true
wpgen data clean || true
rm -f "$DATA_FILE"

log "generate sample file -> $DATA_FILE"
mkdir -p "$(dirname "$DATA_FILE")"
wpgen rule -n "$LINE_CNT" --stat "$STAT_SEC" -o "$DATA_FILE"

if [[ ! -s "$DATA_FILE" ]]; then
  echo "Error: generated file $DATA_FILE is missing or empty" >&2
  exit 1
fi

log "run wparse batch"
if ! wparse batch --stat "$STAT_SEC" -S 1 -p -n "$LINE_CNT"; then
  echo "wparse failed, please inspect ./data/logs/wparse.log" >&2
  exit 1
fi

log "validate sinks"
wproj data stat
wproj data validate --input-cnt "$LINE_CNT"

if command -v mysql >/dev/null 2>&1; then
  log "query Doris table ${DORIS_DB}.${DORIS_TABLE}"
  MYSQL_CMD=(mysql -h"$DORIS_HOST" -P"$DORIS_PORT" -u"$DORIS_USER")
  if [[ -n "$DORIS_PASSWORD" ]]; then
    MYSQL_CMD+=("-p$DORIS_PASSWORD")
  fi
  MYSQL_CMD+=(
    -e "SELECT COUNT(*) AS cnt FROM ${DORIS_DB}.${DORIS_TABLE};"
  )
  if ! "${MYSQL_CMD[@]}"; then
    log "mysql query failed (please confirm Doris service)"
  fi
else
  log "mysql not installed, skip Doris verification"
fi
