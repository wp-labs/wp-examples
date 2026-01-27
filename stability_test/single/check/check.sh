#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$BASE_DIR/.." && pwd)"
CONTEXT_DIR="$BASE_DIR/context"
REPORT_FILE="$BASE_DIR/report.log"
VLOGS_CHECK_SCRIPT="$BASE_DIR/check_vlogs.sh"
DORIS_CHECK_SCRIPT="$BASE_DIR/check_doris.sh"
DOCKER_COMPOSE_CMD="${DOCKER_COMPOSE_CMD:-docker compose}"
RESTART_WAIT="${RESTART_WAIT:-5}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
RUN_ONCE="${RUN_ONCE:-0}"

mkdir -p "$CONTEXT_DIR" "$(dirname "$REPORT_FILE")"

count_expected() {
    local file="$1"
    local keyword="$2"
    if [[ -f "$file" ]]; then
        grep -F -c -- "$keyword" "$file" || true
    else
        echo 0
    fi
}

calculate_expected_counts() {
    local nginx_file="$PROJECT_ROOT/parse/data/out_dat/file-1.dat"
    local jnginx_file="$PROJECT_ROOT/parse/data/out_dat/file-2.dat"

    EXPECT_JNGINX=$(count_expected "$jnginx_file" "\"log_type\":\"jnginx\"")
    EXPECT_NGINX=$(count_expected "$nginx_file" "\"log_type\":\"nginx\"")
}

restart_outputs() {
    echo "[INFO] 重启输出目标（docker compose）" | tee -a "$REPORT_FILE"
    if ! $DOCKER_COMPOSE_CMD restart >/dev/null 2>&1; then
        echo "[WARN] docker compose restart 执行失败" | tee -a "$REPORT_FILE"
    fi
    sleep "$RESTART_WAIT"
}

run_checker() {
    local name="$1"
    local script="$2"

    if [[ ! -x "$script" ]]; then
        echo "[ERROR] checker not found or not executable: $script" | tee -a "$REPORT_FILE"
        return 1
    fi

    local output
    if ! output="$(
        PROJECT_ROOT="$PROJECT_ROOT" \
        CONTEXT_DIR="$CONTEXT_DIR" \
        "$script" "$EXPECT_JNGINX" "$EXPECT_NGINX" 2>&1
    )"; then
        echo "$output" >> "$REPORT_FILE"
        echo "[ERROR] ${name} 执行失败" | tee -a "$REPORT_FILE"
        return 1
    fi

    echo "$output" >> "$REPORT_FILE"
    local filtered
    filtered=$(echo "$output" | grep '^check_' || true)
    if [[ -n "$filtered" ]]; then
        echo "$filtered"
    else
        echo "$output"
    fi
}

main() {
    while true; do
        restart_outputs
        calculate_expected_counts

        echo "==== $(date -u +"%Y-%m-%dT%H:%M:%SZ") ====" >> "$REPORT_FILE"
        echo "预期：jnginx=${EXPECT_JNGINX}，nginx=${EXPECT_NGINX}" | tee -a "$REPORT_FILE"

        run_checker "check_vlogs" "$VLOGS_CHECK_SCRIPT"
        run_checker "check_doris" "$DORIS_CHECK_SCRIPT"

        if [[ "$RUN_ONCE" == "1" ]]; then
            break
        fi

        sleep "$CHECK_INTERVAL"
    done
}

main "$@"
