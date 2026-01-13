#!/bin/bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$BASE_DIR/parse/data/logs"
PID_DIR="$BASE_DIR/pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

VERSION_FILTER="${LOG_VERSION_FILTER:-}"
DOCKER_COMPOSE_CMD=${DOCKER_COMPOSE_CMD:-"docker compose"}
# ============================================
# VictoriaLogs 获取日志总数方法
# ============================================

# 全局时间变量（ISO 8601 UTC）
OS_TYPE=$(uname)

if [[ "$OS_TYPE" == "Linux" ]]; then
    # Linux / GNU date
    END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    START_TIME=$(date -u -d "2 days ago" +"%Y-%m-%dT%H:%M:%SZ")
elif [[ "$OS_TYPE" == "Darwin" ]]; then
    # macOS / BSD date
    END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    START_TIME=$(date -u -v -2d +"%Y-%m-%dT%H:%M:%SZ")
else
    echo "Unsupported OS: $OS_TYPE"
    exit 1
fi

# VictoriaLogs 地址
VLOGS_URL="http://localhost:9428/select/logsql/stats_query"

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
        echo "Error: query_condition is empty"
        return 1
    fi

    # 执行 curl 查询
    local response
    response=$(curl -s -G "$VLOGS_URL" \
        --data-urlencode "query=${query_condition} | stats count()" \
        --data-urlencode "start=${START_TIME}" \
        --data-urlencode "end=${END_TIME}")

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
        echo "[ERROR] 用法: count_log_contains 文件名 关键字"
        return 1
    fi

    if [ ! -f "$file" ]; then
        echo "[ERROR] 文件不存在: $file"
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

    if [[ "$vlog_count" -eq "$file_count" ]]; then
        echo "[OK] ${label}: vlog_count == file_count (${vlog_count})"
        return 0
    fi

    echo "[WARN] ${label}: vlog_count != file_count (vlog=${vlog_count}, file=${file_count})"
    return 1
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
        echo "[ERROR] 请提供进程名称"
        return 1
    fi
    echo "[INFO] 查找进程: $name"
    pids=$(ps -ef | grep "$name" | grep -v grep | awk '{print $2}')
    if [ -z "$pids" ]; then
        echo "[INFO] 未找到相关进程"
        return 0
    fi
    echo "[INFO] 发现进程ID: $pids"
    for pid in $pids; do
        echo "[INFO] 正在终止进程: $pid"
        kill "$pid"
    done
    echo "[INFO] 完成"
}
start_process() {
    local cmd="$1"
    local log_file="$2"

    local workdir="$3"
    local pid_file="$4"

    echo "[INFO] Starting: $cmd (cwd: $workdir)"
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
        echo "[INFO] PID $pid recorded for $cmd"
    )
}

start_all_wpgen() {
    echo "[INFO] 启动全部 wpgen 进程"
    start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" \
        "$LOG_DIR/jnginx-kafka.log" "$BASE_DIR/sender/json-nginx" "$PID_DIR/jnginx-kafka.pid"
    start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" \
        "$LOG_DIR/jnginx-tcp.log" "$BASE_DIR/sender/json-nginx" "$PID_DIR/jnginx-tcp.pid"
    start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" \
        "$LOG_DIR/jnginx-syslog.log" "$BASE_DIR/sender/json-nginx" "$PID_DIR/jnginx-syslog.pid"

    start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" \
        "$LOG_DIR/nginx-kafka.log" "$BASE_DIR/sender/nginx" "$PID_DIR/nginx-kafka.pid"
    start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" \
        "$LOG_DIR/nginx-tcp.log" "$BASE_DIR/sender/nginx" "$PID_DIR/nginx-tcp.pid"
    start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" \
        "$LOG_DIR/nginx-syslog.log" "$BASE_DIR/sender/nginx" "$PID_DIR/nginx-syslog.pid"

    start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" \
        "$LOG_DIR/sys-kafka.log" "$BASE_DIR/sender/sys" "$PID_DIR/sys-kafka.pid"
    start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" \
        "$LOG_DIR/sys-tcp.log" "$BASE_DIR/sender/sys" "$PID_DIR/sys-tcp.pid"
    start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" \
        "$LOG_DIR/sys-syslog.log" "$BASE_DIR/sender/sys" "$PID_DIR/sys-syslog.pid"
}

stop_all_wpgen() {
    echo "[INFO] 停止所有 wpgen 进程"
    kill_by_name wpgen || true
}

restart_docker_compose() {
    echo "[INFO] 重启 docker compose 服务"
    (
        cd "$BASE_DIR"
        # shellcheck disable=SC2206
        local cmd_parts=($DOCKER_COMPOSE_CMD)
        "${cmd_parts[@]}" restart
    )
}

main_loop() {
    while true; do
        restart_docker_compose
        echo "[INFO] docker compose 已重启，等待 10 秒..."
        sleep 10

        stop_all_wpgen

        if ! vlog_check; then
            echo "[WARN] vlog_check 检测到计数不一致"
        fi

        start_all_wpgen
        echo "[INFO] 完成一轮巡检，60 秒后再次执行"
        sleep 60
    done
}

main_loop
