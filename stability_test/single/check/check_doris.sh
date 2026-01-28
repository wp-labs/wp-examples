#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: check_doris.sh <expected_jnginx> <expected_nginx>" >&2
    exit 1
fi

EXPECTED_JNGINX="$1"
EXPECTED_NGINX="$2"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")" && pwd)/context}"
STATE_FILE="$CONTEXT_DIR/check_doris.state"

DORIS_FE_HOST="${DORIS_FE_HOST:-localhost}"
DORIS_FE_PORT="${DORIS_FE_PORT:-8030}"
DORIS_API_PATH="${DORIS_API_PATH:-/api/query/internal/mysql}"
DORIS_USER="${DORIS_USER:-root}"
DORIS_PASS="${DORIS_PASS:-}"
DORIS_DB="${DORIS_DB:-test_db}"
DORIS_TABLE_NGINX="${DORIS_TABLE_NGINX:-wp_nginx}"
DORIS_TABLE_JNGINX="${DORIS_TABLE_JNGINX:-wp_jnginx}"

mkdir -p "$CONTEXT_DIR"

query_doris() {
    local table="$1"
    local sql="SELECT count(*) FROM ${table};"
    local response code value

    if ! response=$(curl -sS -u "${DORIS_USER}:${DORIS_PASS}" \
        -H 'Content-Type: application/json; charset=utf-8' \
        --data "{\"stmt\":\"${sql}\"}" \
        "http://${DORIS_FE_HOST}:${DORIS_FE_PORT}${DORIS_API_PATH}"); then
        echo "[WARN] Failed to query Doris (${table})" >&2
        echo 0
        return
    fi

    code=$(echo "$response" | jq -r '.code // 1' 2>/dev/null || echo "1")
    if [[ "$code" != "0" ]]; then
        echo "[WARN] Doris response for ${table}: $response" >&2
        echo 0
        return
    fi

    value=$(echo "$response" | jq -r '.data.data[0][0]' 2>/dev/null || echo "0")
    echo "$value"
}

actual_jnginx=$(query_doris "${DORIS_DB}.${DORIS_TABLE_JNGINX}")
actual_nginx=$(query_doris "${DORIS_DB}.${DORIS_TABLE_NGINX}")

actual_sum=$((actual_jnginx + actual_nginx))
expected_sum=$((EXPECTED_JNGINX + EXPECTED_NGINX))

prev_sum=0
if [[ -f "$STATE_FILE" ]]; then
    prev_sum=$(cat "$STATE_FILE" 2>/dev/null || echo 0)
fi
last_60=$((actual_sum - prev_sum))
echo "$actual_sum" > "$STATE_FILE"

total_loss=$((expected_sum - actual_sum))
ratio="+0.00%"
if (( expected_sum > 0 )); then
    ratio=$(awk -v loss="$total_loss" -v exp="$expected_sum" 'BEGIN{printf "%+.2f%%", (loss/exp)*100}')
fi

printf 'check_doris：jnginx=%s nginx=%s last_60s=%+d total_loss=%+d ratio=%s\n' \
    "$actual_jnginx" "$actual_nginx" "$last_60" "$total_loss" "$ratio"
