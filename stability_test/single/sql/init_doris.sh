#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: init_doris.sh <fe_host> [be_host] [sql_file]

Arguments:
  <fe_host>   Hostname or IP of the Doris FE service (without protocol).
  [be_host]   Hostname/IP of the Doris BE health endpoint (default: same as fe_host).
  [sql_file]  Path to SQL file to execute (default: /scripts/doris.sql).

Environment:
  FE_PORT       FE HTTP port (default: 8030)
  BE_PORT       BE HTTP port (default: 8040)
  DORIS_USER    Username for FE API (default: root)
  DORIS_PASS    Password for FE API (default: empty)
  DORIS_API     FE API path (default: /api/query/internal/mysql)
EOF
}

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

FE_HOST="$1"
BE_HOST="${2:-$FE_HOST}"
SQL_FILE="${3:-/scripts/doris.sql}"
FE_PORT="${FE_PORT:-8030}"
BE_PORT="${BE_PORT:-8040}"
DORIS_USER="${DORIS_USER:-root}"
DORIS_PASS="${DORIS_PASS:-}"
DORIS_API="${DORIS_API:-/api/query/internal/mysql}"

if [ ! -f "$SQL_FILE" ]; then
  echo "[init-doris] SQL file not found: $SQL_FILE" >&2
  exit 1
fi

CURL_AUTH="-u ${DORIS_USER}:${DORIS_PASS}"

wait_for_endpoint() {
  name="$1"
  url="$2"

  echo "[init-doris] Waiting for $name ($url)"
  until curl -sf "$url" >/dev/null 2>&1; do
    echo "[init-doris] $name not ready, retrying in 5s..."
    sleep 5
  done
  echo "[init-doris] $name is ready."
}

escape_sql() {
  awk '{
    sub(/\r$/, "");
    gsub(/\\/, "\\\\");
    gsub(/"/, "\\\"");
    printf "%s\\n", $0;
  }' "$SQL_FILE"
}

wait_for_endpoint "FE" "http://${FE_HOST}:${FE_PORT}/api/health"
wait_for_endpoint "BE" "http://${BE_HOST}:${BE_PORT}/api/health"

payload="$(escape_sql)"
echo "[init-doris] Sending initialization SQL..."

while true; do
  response="$(curl -sS $CURL_AUTH \
    -H 'Content-Type: application/json; charset=utf-8' \
    --data "{\"stmt\":\"${payload}\"}" \
    "http://${FE_HOST}:${FE_PORT}${DORIS_API}")"

  echo "$response"

  if echo "$response" | grep -Eq '"code"[[:space:]]*:[[:space:]]*0'; then
    echo "[init-doris] Initialization completed successfully."
    break
  fi

  if echo "$response" | grep -q 'available backend num is 0'; then
    echo "[init-doris] Backend not ready according to FE, retrying in 5s..."
    sleep 5
    continue
  fi

  echo "[init-doris] Initialization failed. Exiting."
  exit 1
done
