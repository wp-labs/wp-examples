#!/bin/bash
set -euo pipefail

DEBUG=0
RUN_IN_BACKGROUND=0
while getopts ":db" opt; do
    case "$opt" in
        d) DEBUG=1 ;;
        b) RUN_IN_BACKGROUND=1 ;;
        \?) echo "Usage: $0 [-d]" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "$@"
    fi
}

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$BASE_DIR/parse/data/logs"
PID_DIR="$BASE_DIR/pids"
REPORT_DIR="$BASE_DIR/report"
REPORT_LOG="$REPORT_DIR/vlogs-check.log"
REPORT_MISMATCH_FILE="$REPORT_DIR/vlogs-check-report.log"
mkdir -p "$LOG_DIR" "$PID_DIR" "$REPORT_DIR"

if [[ "$RUN_IN_BACKGROUND" -eq 1 && -z "${VLOGS_CHECK_CHILD:-}" ]]; then
    echo "[INFO] vlogs-check will run in background. Logs: $REPORT_LOG"
    cmd=(env VLOGS_CHECK_CHILD=1 "$0")
    if [[ "$DEBUG" -eq 1 ]]; then
        cmd+=("-d")
    fi
    cmd+=("$@")
    nohup "${cmd[@]}" > "$REPORT_LOG" 2>&1 &
    echo "" > "$REPORT_MISMATCH_FILE"
    bg_pid=$!
    echo "[INFO] Background PID: $bg_pid"
    exit 0
fi

VERSION_FILTER="${LOG_VERSION_FILTER:-}"
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-"docker compose"}
# ============================================
# VictoriaLogs 获取日志总数方法
# ============================================

# 全局时间计算函数
OS_TYPE=$(uname)

compute_time_range() {
    if [[ "$OS_TYPE" == "Linux" ]]; then
        END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        START_TIME=$(date -u -d "2 days ago" +"%Y-%m-%dT%H:%M:%SZ")
    elif [[ "$OS_TYPE" == "Darwin" ]]; then
        END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        START_TIME=$(date -u -v -2d +"%Y-%m-%dT%H:%M:%SZ")
    else
        echo "Unsupported OS: $OS_TYPE"
        exit 1
    fi
}

# VictoriaLogs 地址
VLOGS_URL="http://localhost:9428/select/logsql/stats_query"

normalize_label() {
    echo "$1" | tr '[:lower:]-' '[:upper:]_'
}

format_signed() {
    local value="$1"
    printf "%+d" "$value"
}

# -------------------------------
# 方法：获取日志总条数
# 参数:
#   $1 - LogsQL 查询条件
# 返回:
#   日志总条数
# -------------------------------
get_logs_count() {
    local query_condition="$1"

    if [ -z "$query_condition" ]; then
        log_debug "Error: query_condition is empty"
        return 1
    fi

    compute_time_range

    # 执行 curl 查询
    local response
    response=$(curl -s -G "$VLOGS_URL" \
        --data-urlencode "query=${query_condition} | stats count()" \
        --data-urlencode "start=${START_TIME}" \
        --data-urlencode "end=${END_TIME}")

    # log_debug curl -s -G "${VLOGS_URL}" \
    #     --data-urlencode "query=${query_condition} | stats count()" \
    #     --data-urlencode "start=${START_TIME}" \
    #     --data-urlencode "end=${END_TIME}"

    # 解析 count
    local count
    count=$(echo "$response" | jq -r '.data.result[0].value[1] // 0')

    echo "$count"
}
count_log_contains() {
    local file="$1"
    local keyword="$2"
    local count

    if [ -z "$file" ] || [ -z "$keyword" ]; then
        log_debug "[ERROR] 用法: count_log_contains 文件名 关键字"
        return 1
    fi

    if [ ! -f "$file" ]; then
        log_debug "[ERROR] 文件不存在: $file"
        return 1
    fi

    count=$(grep -F -c -- "$keyword" "$file" || true)
    echo "$count"
}
build_query() {
    local log_type="$1"
    local query="log_type:${log_type}"

    if [[ -n "$VERSION_FILTER" ]]; then
        query+=" and version:${VERSION_FILTER}"
    fi

    echo "$query"
}

compare_counts() {
    local label="$1"
    local vlog_count="$2"
    local file_count="$3"

    local loss_info
    loss_info=$(update_loss_stats "$label" "$file_count" "$vlog_count")
    IFS=: read -r incremental_loss total_loss loss_ratio <<<"$loss_info"

    local incremental_fmt total_fmt
    incremental_fmt=$(format_signed "$incremental_loss")
    total_fmt=$(format_signed "$total_loss")

    if [[ "$vlog_count" -eq "$file_count" ]]; then
        echo "[OK] ${label}: expected == vlogs (${vlog_count})"
        return 0
    fi

    echo "[WARN] ${label}: expected=${file_count} vlogs=${vlog_count} last60s=${incremental_fmt} total_loss=${total_fmt} ratio=${loss_ratio}"
    report_mismatch "$label" "$vlog_count" "$file_count" "$incremental_fmt" "$total_fmt" "$loss_ratio"
    return 1
}

report_mismatch() {
    local label="$1"
    local vlog_count="$2"
    local file_count="$3"
    local period_loss="${4:-0}"
    local total_loss="${5:-0}"
    local loss_ratio="${6:-0%}"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    printf '%s label=%s expected=%s vlogs=%s last60s=%s total_loss=%s ratio=%s\n' \
        "$timestamp" "$label" "$file_count" "$vlog_count" "$period_loss" "$total_loss" "$loss_ratio" >> "$REPORT_MISMATCH_FILE"
}

update_loss_stats() {
    local label="$1"
    local file_count="$2"
    local vlog_count="$3"

    local diff=$((vlog_count - file_count))

    local key
    key=$(normalize_label "$label")
    local prev_var="PREV_DELTA_${key}"

    local prev
    prev=$(eval "echo \${$prev_var:-0}")

    local incremental=$((diff - prev))

    eval "$prev_var=$diff"

    local ratio="0%"
    if (( file_count != 0 )); then
        ratio=$(awk -v d="$diff" -v f="$file_count" 'BEGIN{if (f!=0) printf "%+.2f%%", (d/f)*100; else printf "0%%"}')
    else
        ratio="+0.00%"
    fi

    printf '%s:%s:%s' "$incremental" "$diff" "$ratio"
}

vlog_check(){
    local nginx_query jnginx_query
    nginx_query=$(build_query "nginx")
    jnginx_query=$(build_query "jnginx")

    local nginx_vlog_cnt jnginx_vlog_cnt nginx_file_cnt jnginx_file_cnt status=0
    nginx_vlog_cnt=$(get_logs_count "$nginx_query")
    jnginx_vlog_cnt=$(get_logs_count "$jnginx_query")

    nginx_file_cnt=$(count_log_contains "$BASE_DIR/parse/data/out_dat/file-1.dat" "\"log_type\":\"nginx\"")
    jnginx_file_cnt=$(count_log_contains "$BASE_DIR/parse/data/out_dat/file-2.dat" "\"log_type\":\"jnginx\"")

    echo "[INFO] nginx_vlog_cnt = $nginx_vlog_cnt"
    echo "[INFO] jnginx_vlog_cnt = $jnginx_vlog_cnt"
    echo "[INFO] nginx_file_cnt = $nginx_file_cnt"
    echo "[INFO] jnginx_file_cnt = $jnginx_file_cnt"

    compare_counts "nginx" "$nginx_vlog_cnt" "$nginx_file_cnt" || status=1
    compare_counts "jnginx" "$jnginx_vlog_cnt" "$jnginx_file_cnt" || status=1

    return $status
}

kill_by_name() {
    local name="$1"

    if [ -z "$name" ]; then
        log_debug "[ERROR] 请提供进程名称"
        return 1
    fi
    log_debug "[INFO] 查找进程: $name"
    pids=$(ps -ef | grep "$name" | grep -v grep | awk '{print $2}')
    if [ -z "$pids" ]; then
        log_debug "[INFO] 未找到相关进程"
        return 0
    fi
    log_debug "[INFO] 发现进程ID: $pids"
    for pid in $pids; do
        log_debug "[INFO] 正在终止进程: $pid"
        kill -9 "$pid"
    done
    log_debug "[INFO] 完成"
}
start_process() {
    local cmd="$1"
    local log_file="$2"

    local workdir="$3"
    local pid_file="$4"

    log_debug "[INFO] Starting: $cmd (cwd: $workdir)"
    mkdir -p "$(dirname "$log_file")"

    (
        cd "$workdir"
        if [ "$OS_TYPE" = "Linux" ]; then
            nohup bash -c "$cmd" > "$log_file" 2>&1 &
        else
            bash -c "$cmd" > "$log_file" 2>&1 &
        fi
        local pid=$!
        if [[ -n "$pid_file" ]]; then
            echo "$pid" > "$pid_file"
        fi
        log_debug "[INFO] PID $pid recorded for $cmd"
    )
}

start_all_wpgen() {
    log_debug "[INFO] 启动全部 wpgen 进程"
    local parse_dir="$BASE_DIR/parse"

    start_process "wpgen sample -c jnginx-kafka.toml --wpl ./models/wpl/nginx/jnginx --stat 2 -p" \
        "$LOG_DIR/jnginx-kafka.log" "$parse_dir" ""
    start_process "wpgen sample -c jnginx-tcp.toml --wpl ./models/wpl/nginx/jnginx --stat 2 -p" \
        "$LOG_DIR/jnginx-tcp.log" "$parse_dir" ""
    start_process "wpgen sample -c jnginx-syslog.toml --wpl ./models/wpl/nginx/jnginx --stat 2 -p" \
        "$LOG_DIR/jnginx-syslog.log" "$parse_dir" ""

    start_process "wpgen sample -c nginx-kafka.toml --wpl ./models/wpl/nginx/nginx --stat 2 -p" \
        "$LOG_DIR/nginx-kafka.log" "$parse_dir" ""
    start_process "wpgen sample -c nginx-tcp.toml --wpl ./models/wpl/nginx/nginx --stat 2 -p" \
        "$LOG_DIR/nginx-tcp.log" "$parse_dir" ""
    start_process "wpgen sample -c nginx-syslog.toml --wpl ./models/wpl/nginx/nginx --stat 2 -p" \
        "$LOG_DIR/nginx-syslog.log" "$parse_dir" ""

    start_process "wpgen sample -c sys-kafka.toml --wpl ./models/wpl/sys --stat 2 -p" \
        "$LOG_DIR/sys-kafka.log" "$parse_dir" ""
    start_process "wpgen sample -c sys-tcp.toml --wpl ./models/wpl/sys --stat 2 -p" \
        "$LOG_DIR/sys-tcp.log" "$parse_dir" ""
    start_process "wpgen sample -c sys-syslog.toml --wpl ./models/wpl/sys --stat 2 -p" \
        "$LOG_DIR/sys-syslog.log" "$parse_dir" ""
}

stop_all_wpgen() {
    log_debug "[INFO] 停止所有 wpgen 进程"
    kill_by_name wpgen || true
}

restart_docker_compose() {
    log_debug "[INFO] 重启 docker compose 服务"
    (
        cd "$BASE_DIR"
        # shellcheck disable=SC2206
        local cmd_parts=($DOCKER_COMPOSE_CMD)
        if [[ "$DEBUG" -eq 1 ]]; then
            "${cmd_parts[@]}" restart
        else
            "${cmd_parts[@]}" restart >/dev/null
        fi
    )
}

main_loop() {
    while true; do

        if ! vlog_check; then
            echo "[WARN] vlog_check 检测到计数不一致"
        fi

        restart_docker_compose
        log_debug "[INFO] docker compose 已重启，等待 5 秒..."
        sleep 5

        stop_all_wpgen
        log_debug "[INFO] 停止所有发送"
        sleep 5

        if ! vlog_check; then
            echo "[WARN] vlog_check 检测到计数不一致"
        fi

        start_all_wpgen
        log_debug "[INFO] 完成一轮巡检，60 秒后再次执行"
        sleep 60
    done
}

main_loop
