#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: check_vlogs.sh <expected_jnginx> <expected_nginx>" >&2
    exit 1
fi

EXPECTED_JNGINX="$1"
EXPECTED_NGINX="$2"
PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
CONTEXT_DIR="${CONTEXT_DIR:-$(cd "$(dirname "$0")" && pwd)/context}"
STATE_FILE="$CONTEXT_DIR/check_vlogs.state"
VLOGS_URL="${VLOGS_URL:-http://localhost:9428/select/logsql/stats_query}"

mkdir -p "$CONTEXT_DIR"

compute_time_range() {
    if [[ "$(uname)" == "Darwin" ]]; then
        END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        START_TIME=$(date -u -v -2d +"%Y-%m-%dT%H:%M:%SZ")
    else
        END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        START_TIME=$(date -u -d "2 days ago" +"%Y-%m-%dT%H:%M:%SZ")
    fi
}

get_logs_count() {
    local log_type="$1"
    compute_time_range
    local response
    response=$(curl -s -G "$VLOGS_URL" \
        --data-urlencode "query=log_type:${log_type} | stats count()" \
        --data-urlencode "start=${START_TIME}" \
        --data-urlencode "end=${END_TIME}") || echo "{}"
    echo "$response" | jq -r '.data.result[0].value[1] // 0'
}

actual_jnginx=$(get_logs_count "jnginx")
actual_nginx=$(get_logs_count "nginx")

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

printf 'check_vlogs：jnginx=%s nginx=%s last_60s=%+d total_loss=%+d ratio=%s\n' \
    "$actual_jnginx" "$actual_nginx" "$last_60" "$total_loss" "$ratio"
