#!/usr/bin/env bash
set -euo pipefail

# =========================
# 记录初始目录（关键）
# =========================
ORIG_DIR="$(pwd)"

# =========================
# 基础配置
# =========================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$BASE_DIR/parse/data/logs"
PID_DIR="$BASE_DIR/pids"

mkdir -p "$LOG_DIR" "$PID_DIR"

# =========================
# 启动 docker
# =========================
# docker compose up -d

# =========================
# 进入工作目录
# =========================


# =========================
# 启动后台进程并记录 PID
# =========================
start_process() {
    local cmd="$1"
    local log_file="$2"
    local pid_file="$3"

    echo "[INFO] Starting: $cmd"
    OS="$(uname -s)"
    if [ "$OS" = "Linux" ]; then
        nohup $cmd > "$log_file" 2>&1 &
    else
        $cmd > "$log_file" 2>&1 &
    fi
    echo $! > "$pid_file"
    echo "[INFO] PID $! recorded in $pid_file"
}

# 启动各个进程
cd $BASE_DIR/parse
start_process "wparse daemon --stat 2 -p" "$LOG_DIR/wparse-info.log" "$PID_DIR/wparse.pid"
sleep 1

cd $BASE_DIR/sender/json-nginx
start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" "$LOG_DIR/jnginx-kafka.log" "$PID_DIR/jnginx-kafka.pid"
start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" "$LOG_DIR/jnginx-tcp.log" "$PID_DIR/jnginx-tcp.pid"
start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" "$LOG_DIR/jnginx-syslog.log" "$PID_DIR/jnginx-syslog.pid"

cd $BASE_DIR/sender/nginx
start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" "$LOG_DIR/nginx-kafka.log" "$PID_DIR/nginx-kafka.pid"
start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" "$LOG_DIR/nginx-tcp.log" "$PID_DIR/nginx-tcp.pid"
start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" "$LOG_DIR/nginx-syslog.log" "$PID_DIR/nginx-syslog.pid"

cd $BASE_DIR/sender/sys
start_process "wpgen sample -c wpgen-kafka.toml --stat 2 -p" "$LOG_DIR/sys-kafka.log" "$PID_DIR/sys-kafka.pid"
start_process "wpgen sample -c wpgen-tcp.toml --stat 2 -p" "$LOG_DIR/sys-tcp.log" "$PID_DIR/sys-tcp.pid"
start_process "wpgen sample -c wpgen-syslog.toml --stat 2 -p" "$LOG_DIR/sys-syslog.log" "$PID_DIR/sys-syslog.pid"

echo "[INFO] All processes started. PIDs stored in $PID_DIR."

# =========================
# 阻塞主进程（可选）
# =========================
# 如果希望脚本直接结束，不阻塞，可以注释掉 wait
# wait
